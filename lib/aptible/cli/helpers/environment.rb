require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Environment
        include Helpers::Token

        def scoped_environments(options)
          if options[:environment]
            if (environment = environment_from_handle(options[:environment]))
              [environment]
            else
              raise Thor::Error, 'Specified account does not exist'
            end
          else
            Aptible::Api::Account.all(token: fetch_token)
          end
        end

        def ensure_environment(options = {})
          if (handle = options[:environment])
            environment = environment_from_handle(handle)
            return environment if environment
            raise Thor::Error, "Could not find environment #{handle}"
          else
            ensure_default_environment
          end
        end

        def environment_from_handle(handle)
          return nil unless handle
          Aptible::Api::Account.all(token: fetch_token).find do |a|
            a.handle == handle
          end
        end

        def ensure_default_environment
          environments = Aptible::Api::Account.all(token: fetch_token)
          case environments.count
          when 0
            e = 'No environments. Go to https://app.aptible.com/ to proceed'
            raise Thor::Error, e
          when 1
            return environments.first
          else
            raise Thor::Error, <<-ERR.gsub(/\s+/, ' ').strip
              Multiple environments available, please specify with --environment or --env
            ERR
          end
        end
      end
    end
  end
end
