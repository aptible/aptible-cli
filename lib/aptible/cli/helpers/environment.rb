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
          return environments.first if environments.count == 1

          raise Thor::Error, <<-ERR.gsub(/\s+/, ' ').strip
            Multiple environments available, please specify with --environment
          ERR
        end
      end
    end
  end
end
