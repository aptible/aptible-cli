require 'ostruct'

module Aptible
  module CLI
    module Subcommands
      module AiTokens
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Environment
            include Helpers::Telemetry

            desc 'ai:tokens:create', 'Create a new AI token'
            option :environment, aliases: '--env', desc: 'Environment to create the token in'
            option :name, type: :string, desc: 'Name for the AI token'
            define_method 'ai:tokens:create' do
              # telemetry(__method__, options)

              account = ensure_environment(options)

              # POST /accounts/:account_id/ai_tokens
              ai_token_resource = Aptible::Api::Resource.new(token: fetch_token)
              ai_token_resource.href = "#{account.href}/ai_tokens"

              params = {}
              params[:name] = options[:name] if options[:name]

              response = ai_token_resource.post(params)

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  node.value('id', response.id)
                  node.value('name', response.name)
                  # Use attributes[] to avoid collision with HyperResource's auth token property
                  token_value = response.attributes['token']
                  node.value('token', token_value) if token_value
                  node.value('created_at', response.created_at)
                end
              end

              token_value = response.attributes['token']
              if token_value
                CLI.logger.warn "\nSave the token value now - it will not be shown again!"
              end
            rescue HyperResource::ClientError, HyperResource::ServerError => e
              # Extract clean error message from response
              error_message = if e.respond_to?(:body) && e.body.is_a?(Hash)
                                e.body['error'] || e.message
                              else
                                e.message
                              end
              raise Thor::Error, error_message
            end

            desc 'ai:tokens:list', 'List all AI tokens'
            option :environment, aliases: '--env', desc: 'Environment to list tokens from'
            define_method 'ai:tokens:list' do
              # telemetry(__method__, options)

              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'handle'
                ) do |node|
                  accounts = scoped_environments(options)

                  accounts.each do |account|
                    # GET /accounts/:account_id/ai_tokens
                    ai_tokens_resource = Aptible::Api::Resource.new(token: fetch_token)
                    ai_tokens_resource.href = "#{account.href}/ai_tokens"

                    begin
                      response = ai_tokens_resource.get
                      
                      # HyperResource stores parsed JSON in the body attribute
                      # Access the _embedded.ai_tokens array from the body
                      tokens = if response.body && response.body['_embedded'] && response.body['_embedded']['ai_tokens']
                                 embedded_tokens = response.body['_embedded']['ai_tokens']
                                 # Convert hashes to OpenStruct for dot notation access
                                 # Add the account handle for grouped list formatting
                                 embedded_tokens.map do |token_data|
                                   OpenStruct.new(token_data.merge('handle' => account.handle))
                                 end
                               else
                                 []
                               end

                      tokens.each do |ai_token|
                        node.object do |n|
                          # Show ID and name for text output, all fields for JSON
                          n.value('handle', "#{ai_token.id} #{ai_token.name}")
                          n.value('id', ai_token.id)
                          n.value('name', ai_token.name)
                          n.value('created_at', ai_token.created_at)
                          n.value('last_used_at', ai_token.last_used_at) if ai_token.respond_to?(:last_used_at)
                          
                          # Create nested environment structure for grouped_keyed_list
                          n.keyed_object('environment', 'handle') do |env|
                            env.value('handle', account.handle)
                          end
                        end
                      end
                    rescue HyperResource::ClientError => e
                      # Skip if endpoint not available for this account
                      next if e.response.status == 404
                      raise
                    end
                  end
                end
              end
            end

            desc 'ai:tokens:show GUID', 'Show details of an AI token'
            define_method 'ai:tokens:show' do |guid|
              # telemetry(__method__, options.merge(guid: guid))

              # GET /ai_tokens/:guid via HAL
              ai_token_resource = Aptible::Api::Resource.new(token: fetch_token)
              ai_token_resource.href = "/ai_tokens/#{guid}"

              begin
                response = ai_token_resource.get
                
                # Parse the response from body
                token_data = if response.body
                               OpenStruct.new(response.body)
                             else
                               raise Thor::Error, "No data received for token #{guid}"
                             end

                Formatter.render(Renderer.current) do |root|
                  root.object do |node|
                    node.value('id', token_data.id)
                    node.value('name', token_data.name)
                    node.value('created_at', token_data.created_at)
                    node.value('updated_at', token_data.updated_at)
                    node.value('last_used_at', token_data.last_used_at) if token_data.respond_to?(:last_used_at)
                    node.value('revoked_at', token_data.revoked_at) if token_data.respond_to?(:revoked_at)
                  end
                end
              rescue HyperResource::ClientError => e
                if e.response.status == 404
                  raise Thor::Error, "AI token #{guid} not found or access denied"
                else
                  raise Thor::Error, "Failed to retrieve token: #{e.message}"
                end
              end
            end

            desc 'ai:tokens:revoke GUID', 'Revoke an AI token'
            define_method 'ai:tokens:revoke' do |guid|
              # telemetry(__method__, options.merge(guid: guid))

              # DELETE /ai_tokens/:guid via HAL
              ai_token = Aptible::Api::Resource.new(token: fetch_token)
              ai_token.href = "/ai_tokens/#{guid}"

              begin
                ai_token.delete
                CLI.logger.info 'AI token revoked successfully'
              rescue HyperResource::ClientError => e
                if e.response.status == 404
                  raise Thor::Error, "AI token #{guid} not found or access denied"
                else
                  raise Thor::Error, "Failed to revoke token: #{e.message}"
                end
              end
            end
          end
        end
      end
    end
  end
end

