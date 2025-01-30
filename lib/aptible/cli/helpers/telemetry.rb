require 'httpclient'
require 'securerandom'
require 'uri'

module Aptible
  module CLI
    module Helpers
      module Telemetry
        def telemetry(cmd, options = {})
          token_hash = decode_token
          format = Renderer.format
          sub = token_hash[0]['sub']
          parsed_url = URI.parse(sub)
          path_components = parsed_url.path.split('/')
          user_or_org_id = path_components.last
          client = HTTPClient.new

          value = {
            'email' => token_hash[0]['email'],
            'format' => format,
            'cmd' => cmd,
            'options' => options
          }
          response = nil

          begin
            uri = URI("https://tuna.aptible.com/www/e")
            response = client.get(uri, {
              'id' => SecureRandom.uuid,
              'user_id' => user_or_org_id,
              'type' => 'cli_telemetry',
              'url' => sub,
              'value' => value
            })
          rescue => e
            # since this is just for telemetry we don't want to notify
            # user of an error
            # puts "Error: #{e.message}"
          end
        end
      end
    end
  end
end
