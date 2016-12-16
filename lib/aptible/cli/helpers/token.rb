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
          File.open(token_file, 'w') do |file|
            file.puts hash.to_json
          end
        rescue
          raise Thor::Error, <<-ERR.gsub(/\s+/, ' ').strip
            Could not write token to #{token_file}, please check filesystem
            permissions
          ERR
        end

        def current_token_hash
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
