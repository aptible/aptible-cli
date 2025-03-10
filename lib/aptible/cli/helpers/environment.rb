require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Environment
        include Helpers::Token

        def environment_href
          href = '/accounts'
          if Renderer.format != 'json'
            href = '/accounts?per_page=5000&no_embed=true'
          end
          href
        end

        def scoped_environments(options)
          if options[:environment]
            if (environment = environment_from_handle(options[:environment]))
              [environment]
            else
              raise Thor::Error, 'Specified account does not exist'
            end
          else
            href = environment_href
            Aptible::Api::Account.all(
              token: fetch_token,
              href: href
            )
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

          url = "/search/account?handle=#{handle}"
          Aptible::Api::Account.find_by_url(
            url,
            token: fetch_token
          )
        end

        def environment_map(accounts)
          acc_map = {}
          accounts.each do |account|
            acc_map[account.links.self.href] = account
          end
          acc_map
        end

        def ensure_default_environment
          href = environment_href
          environments = Aptible::Api::Account.all(
            token: fetch_token,
            href: href
          )
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
