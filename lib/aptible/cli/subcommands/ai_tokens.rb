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
              telemetry(__method__, options)

              account = ensure_environment(options)

              # POST /accounts/:account_id/ai_tokens
              ai_token_resource = Aptible::Api::Resource.new(token: fetch_token)
              ai_token_resource.href = "#{account.href}/ai_tokens"
              
              params = {}
              params[:name] = options[:name] if options[:name]
              
              response = ai_token_resource.post(params)

              Formatter.render(Renderer.current) do |root|
                root.keyed_object('ai_token') do |node|
                  node.value('id', response.id)
                  node.value('name', response.name)
                  node.value('token', response.token) if response.respond_to?(:token) && response.token
                  node.value('created_at', response.created_at)
                end
              end

              CLI.logger.info 'AI token created successfully'
              CLI.logger.warn 'Save the token value now - it will not be shown again!' if response.respond_to?(:token) && response.token
            end

            desc 'ai:tokens:list', 'List all AI tokens'
            option :environment, aliases: '--env', desc: 'Environment to list tokens from'
            define_method 'ai:tokens:list' do
              telemetry(__method__, options)

              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'id'
                ) do |node|
                  accounts = scoped_environments(options)

                  accounts.each do |account|
                    # GET /accounts/:account_id/ai_tokens
                    ai_tokens_resource = Aptible::Api::Resource.new(token: fetch_token)
                    ai_tokens_resource.href = "#{account.href}/ai_tokens"
                    
                    begin
                      response = ai_tokens_resource.get
                      tokens = response._embedded&.ai_tokens || []

                      tokens.each do |ai_token|
                        node.object do |n|
                          n.value('id', ai_token.id)
                          n.value('name', ai_token.name)
                          n.value('environment', account.handle)
                          n.value('created_at', ai_token.created_at)
                          n.value('last_used_at', ai_token.last_used_at) if ai_token.respond_to?(:last_used_at)
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

            desc 'ai:tokens:revoke GUID', 'Revoke an AI token'
            define_method 'ai:tokens:revoke' do |guid|
              telemetry(__method__, options.merge(guid: guid))

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

