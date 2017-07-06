require 'aptible/auth'

module Aptible
  module CLI
    module Helpers
      module Token
        TOKEN_ENV_VAR = 'APTIBLE_ACCESS_TOKEN'.freeze

        def fetch_token
          @token ||= ENV[TOKEN_ENV_VAR] ||
                     current_token_hash[Aptible::Auth.configuration.root_url]
          return @token if @token
          raise Thor::Error, 'Could not read token: please run aptible login ' \
                             "or set #{TOKEN_ENV_VAR}"
        end

        def save_token(token)
          hash = current_token_hash.merge(
            Aptible::Auth.configuration.root_url => token
          )

          FileUtils.mkdir_p(File.dirname(token_file))

          File.open(token_file, 'w', 0o600) do |file|
            file.puts hash.to_json
          end
        rescue StandardError => e
          m = "Could not write token to #{token_file}: #{e}. " \
              'Check filesystem permissions.'
          raise Thor::Error, m
        end

        def current_token_hash
          # NOTE: older versions of the CLI did not properly create the
          # token_file with mode 600, which is why we update it when reading.
          File.chmod(0o600, token_file)
          JSON.parse(File.read(token_file))
        rescue
          {}
        end

        def token_file
          File.join ENV['HOME'], '.aptible', 'tokens.json'
        end
      end
    end
  end
end
