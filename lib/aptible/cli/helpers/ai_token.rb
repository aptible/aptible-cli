module Aptible
  module CLI
    module Helpers
      module AiToken
        include Helpers::Token

        def ensure_ai_token(account, id)
          ai_tokens = account.ai_tokens.select { |t| t.id.to_s == id.to_s }

          if ai_tokens.empty?
            raise Thor::Error, "AI token #{id} not found or access denied"
          end

          ai_tokens.first
        rescue HyperResource::ClientError => e
          if e.response.status == 404
            raise Thor::Error, "AI token #{id} not found or access denied"
          else
            raise Thor::Error, "Failed to retrieve token: #{e.message}"
          end
        end

        def create_ai_token(account, opts)
          ai_token = account.create_ai_token!(opts)
          
          # Log full HAL response in debug mode
          if ENV['APTIBLE_DEBUG'] == 'DEBUG'
            begin
              CLI.logger.warn "POST create response: #{JSON.pretty_generate(ai_token.body)}"
            rescue StandardError
              CLI.logger.warn "POST create response: #{ai_token.body.inspect}"
            end
          end
          
          Formatter.render(Renderer.current) do |root|
            root.object do |node|
              ResourceFormatter.inject_ai_token(node, ai_token, account)
              
              # Include the token value on creation if present
              token_value = ai_token.attributes['token']
              node.value('token', token_value) if token_value
            end
          end

          # Warn about token value and gateway URL if present
          token_value = ai_token.attributes['token']
          gateway_url = ai_token.attributes['gateway_url']
          if token_value
            CLI.logger.warn "\nSave the token value now - it will not be shown again!"
            if gateway_url
              CLI.logger.warn "Use this token to authenticate requests to: #{gateway_url}"
            end
          end

          ai_token
        rescue HyperResource::ClientError, HyperResource::ServerError => e
          # Log response body in debug mode
          if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.respond_to?(:response) && e.response
            begin
              body = e.response.body
              parsed_body = body.is_a?(String) ? JSON.parse(body) : body
              CLI.logger.warn "POST create error response (#{e.response.status}): #{JSON.pretty_generate(parsed_body)}"
            rescue StandardError
              CLI.logger.warn "POST create error response (#{e.response.status}): #{e.response.body.inspect}"
            end
          end

          # Extract clean error message from response
          error_message = if e.respond_to?(:body) && e.body.is_a?(Hash)
                            e.body['error'] || e.message
                          elsif e.respond_to?(:response) && e.response&.status
                            "Failed to create token: HTTP #{e.response.status}"
                          else
                            e.message
                          end
          raise Thor::Error, error_message
        rescue HyperResource::ResponseError => e
          # Log response body in debug mode
          if ENV['APTIBLE_DEBUG'] == 'DEBUG' && e.response
            begin
              body = e.response.body
              parsed_body = body.is_a?(String) ? JSON.parse(body) : body
              CLI.logger.warn "POST create response error (#{e.response.status}): #{JSON.pretty_generate(parsed_body)}"
            rescue StandardError
              CLI.logger.warn "POST create response error (#{e.response.status}): #{e.response.body.inspect}"
            end
          end

          raise Thor::Error, "Failed to create token: HTTP #{e.response&.status || 'unknown error'}"
        end
      end
    end
  end
end
