module Aptible
  module CLI
    module Subcommands
      module AiTokens
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Environment
            include Helpers::AiToken
            include Helpers::Telemetry

            desc 'ai:tokens:create [--environment ENVIRONMENT_HANDLE] [--note NOTE]',
                 'Create a new AI token'
            option :environment, aliases: '--env', desc: 'Environment to create the token in'
            option :note, type: :string, desc: 'Optional note to describe the token (max 256 chars)'
            define_method 'ai:tokens:create' do
              telemetry(__method__, options)

              account = ensure_environment(options)

              opts = {}
              if options[:note]
                # URL-safe base64 encode the note for safe transport to deploy-api
                # deploy-api will validate and encrypt it before storing in LiteLLM
                require 'base64'
                opts[:note] = Base64.urlsafe_encode64(options[:note], padding: true)
              end

              create_ai_token(account, opts)
            end

            desc 'ai:tokens:list [--environment ENVIRONMENT_HANDLE]',
                 'List all AI tokens'
            option :environment, aliases: '--env', desc: 'Environment to list tokens from'
            define_method 'ai:tokens:list' do
              telemetry(__method__, options)

              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'display'
                ) do |node|
                  accounts = scoped_environments(options)

                  accounts.each do |account|
                    begin
                      # Fetch tokens collection
                      tokens = account.ai_tokens
                      next unless tokens # Skip if no tokens available

                      # Log full HAL response in debug mode (single API call returns all tokens)
                      if ENV['APTIBLE_DEBUG'] == 'DEBUG'
                        begin
                          tokens_array = tokens.map(&:body)
                          CLI.logger.warn "GET /accounts/#{account.id}/ai_tokens response: #{JSON.pretty_generate(tokens_array)}"
                        rescue StandardError
                          CLI.logger.warn "GET /accounts/#{account.id}/ai_tokens response: #{tokens.map(&:body).inspect}"
                        end
                      end

                      tokens.each do |ai_token|
                        node.object do |n|
                          ResourceFormatter.inject_ai_token(n, ai_token, account, include_display: true)
                        end
                      end
                    rescue HyperResource::ClientError => e
                      error_message = extract_api_error(e)

                      # Log response body in debug mode
                      if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.response
                        CLI.logger.warn "GET list error response (#{e.response.status}): #{error_message}"
                      end

                      # Skip if endpoint not available for this account
                      if e.response&.status == 404
                        next
                      elsif e.response&.status == 401 || e.response&.status == 403
                        raise Thor::Error, error_message
                      else
                        raise Thor::Error, "Failed to list tokens: #{error_message}"
                      end
                    rescue HyperResource::ResponseError => e
                      error_message = extract_api_error(e)

                      # Log response body in debug mode
                      if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.response
                        CLI.logger.warn "GET list response error (#{e.response.status}): #{error_message}"
                      end

                      raise Thor::Error, "Failed to list tokens: #{error_message}"
                    end
                  end
                end
              end
            end

            desc 'ai:tokens:show ID', 'Show details of an AI token'
            define_method 'ai:tokens:show' do |id|
              telemetry(__method__, options.merge(id: id))

              # GET /ai_tokens/:id via HAL
              # Must set root URL explicitly for the request to work
              api_root = Aptible::Api.configuration.root_url
              ai_token = Aptible::Api::AiToken.new(
                root: api_root,
                token: fetch_token
              )
              ai_token.href = "#{api_root}/ai_tokens/#{id}"

              begin
                ai_token = ai_token.get

                # Log full HAL response in debug mode
                if ENV['APTIBLE_DEBUG'] == 'DEBUG'
                  begin
                    CLI.logger.warn "GET show response: #{JSON.pretty_generate(ai_token.body)}"
                  rescue StandardError
                    CLI.logger.warn "GET show response: #{ai_token.body.inspect}"
                  end
                end

                # Get account from token's link if available
                account = nil
                if ai_token.links && ai_token.links.account
                  begin
                    account = Aptible::Api::Account.new(
                      token: fetch_token
                    ).find_by_url(ai_token.links.account.href)
                  rescue StandardError
                    # If we can't fetch the account, continue without it
                    account = nil
                  end
                end

                Formatter.render(Renderer.current) do |root|
                  root.object do |node|
                    ResourceFormatter.inject_ai_token(node, ai_token, account)
                  end
                end
              rescue HyperResource::ClientError => e
                error_message = extract_api_error(e)

                # Log response body in debug mode
                if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.response
                  CLI.logger.warn "GET show error response (#{e.response.status}): #{error_message}"
                end

                if e.response&.status == 404
                  raise Thor::Error, "AI token #{id} not found or access denied"
                elsif e.response&.status == 401 || e.response&.status == 403
                  raise Thor::Error, error_message
                else
                  raise Thor::Error, "Failed to retrieve token: #{error_message}"
                end
              rescue HyperResource::ResponseError => e
                error_message = extract_api_error(e)

                # Log response body in debug mode
                if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.response
                  CLI.logger.warn "GET show response error (#{e.response.status}): #{error_message}"
                end

                raise Thor::Error, "Failed to retrieve token: #{error_message}"
              end
            end

            desc 'ai:tokens:revoke ID', 'Revoke an AI token'
            define_method 'ai:tokens:revoke' do |id|
              telemetry(__method__, options.merge(id: id))

              # First, fetch the token to verify it exists and get a proper resource
              api_root = Aptible::Api.configuration.root_url
              url = "#{api_root}/ai_tokens/#{id}"

              begin
                ai_token = Aptible::Api::AiToken.new(token: fetch_token)
                              .find_by_url(url)
                raise Thor::Error, "AI token #{id} not found" if ai_token.nil?

                # Log full HAL response in debug mode
                if ENV['APTIBLE_DEBUG'] == 'DEBUG'
                  begin
                    CLI.logger.warn "GET response: #{JSON.pretty_generate(ai_token.body)}"
                  rescue StandardError
                    CLI.logger.warn "GET response: #{ai_token.body.inspect}"
                  end
                end

                # Check if already revoked before attempting DELETE
                if ai_token.blocked
                  raise Thor::Error, 'Token has already been revoked'
                end

                revoked_token = ai_token.delete

                # Log DELETE response in debug mode
                if ENV['APTIBLE_DEBUG'] == 'DEBUG'
                  if ai_token.response
                    response_body = ai_token.response.body
                    if response_body && !response_body.empty?
                      begin
                        CLI.logger.warn "DELETE response (#{ai_token.response.status}): #{JSON.pretty_generate(JSON.parse(response_body))}"
                      rescue StandardError
                        CLI.logger.warn "DELETE response (#{ai_token.response.status}): #{response_body.inspect}"
                      end
                    else
                      CLI.logger.warn "DELETE response (#{ai_token.response.status}): <empty body>"
                    end
                  end
                end

                # Render the revoked token (supports JSON output format)
                Formatter.render(Renderer.current) do |root|
                  root.object do |node|
                    # Get account from token's link if available
                    account = nil
                    if revoked_token&.links && revoked_token.links.account
                      begin
                        account = Aptible::Api::Account.new(
                          token: fetch_token
                        ).find_by_url(revoked_token.links.account.href)
                      rescue StandardError
                        # If we can't fetch the account, continue without it
                        account = nil
                      end
                    end

                    ResourceFormatter.inject_ai_token(node, revoked_token || ai_token, account)
                  end
                end

                CLI.logger.info "\nAI token revoked successfully"
              rescue HyperResource::ClientError => e
                error_message = extract_api_error(e)

                # Log response body in debug mode
                if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.response
                  CLI.logger.warn "DELETE error response (#{e.response.status}): #{error_message}"
                end

                if e.response&.status == 404
                  raise Thor::Error, "AI token #{id} not found or access denied"
                elsif e.response&.status == 401 || e.response&.status == 403
                  raise Thor::Error, error_message
                else
                  raise Thor::Error, "Failed to revoke token: #{error_message}"
                end
              end
              # Note: HyperResource::ResponseError from empty 204 body is caught by
              # Aptible::Resource::Base#delete (returns nil), so delete succeeds silently
            end

            private

            # Extract error message from HyperResource error response
            def extract_api_error(error)
              return error.message unless error.response

              body = error.response.body
              parsed = body.is_a?(String) ? JSON.parse(body) : body
              parsed['error'] || parsed.to_s
            rescue StandardError
              error.message
            end
          end
        end
      end
    end
  end
end
