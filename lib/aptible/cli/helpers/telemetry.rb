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
          format = 'text' if format.nil?
          sub = token_hash[0]['sub']
          parsed_url = URI.parse(sub)
          path_components = parsed_url.path.split('/')
          user_or_org_id = path_components.last
          # https://github.com/aptible/aptible-resource/blob/7c3a79e6eee9c88aa7dbf332e550508f22a5b08d/lib/hyper_resource/modules/http.rb#L21
          client = HTTPClient.new.tap do |c|
            c.cookie_manager = nil
            c.connect_timeout = 30
            c.send_timeout = 45
            c.keep_alive_timeout = 15
            c.ssl_config.set_default_paths
          end

          value = {
            'email' => token_hash[0]['email'],
            'format' => format,
            'cmd' => cmd,
            'options' => options,
            'version' => version_string,
            # https://stackoverflow.com/a/73973555
            'github' => ENV['GITHUB_ACTIONS'],
            'gitlab' => ENV['GITLAB_CI'],
            'travis' => ENV['TRAVIS'],
            'circleci' => ENV['CIRCLECI'],
            'ci' => ENV['CI']
          }

          begin
            uri = URI('https://tuna.aptible.com/www/e')
            client.get(
              uri,
              'id' => SecureRandom.uuid,
              'user_id' => user_or_org_id,
              'type' => 'cli_telemetry',
              'url' => sub,
              'value' => value
            )
          rescue
            # since this is just for telemetry we don't want to notify
            # user of an error
          end
        end
      end
    end
  end
end
