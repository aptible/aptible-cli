require 'aptible/api'
require 'git'

module Aptible
  module CLI
    module Helpers
      module Account
        include Helpers::Token

        def appropriate_accounts(options)
          if options[:account]
            if (account = account_from_handle(options[:account]))
              [account]
            else
              fail Thor::Error, 'Specified account does not exist'
            end
          else
            Aptible::Api::Account.all(token: fetch_token)
          end
        end

        def ensure_account(options = {})
          if (handle = options[:account])
            account = account_from_handle(handle)
            return account if account
            fail "Could not find account #{handle}"
          else
            ensure_default_account
          end
        end

        def account_from_handle(handle)
          Aptible::Api::Account.all(token: fetch_token).find do |a|
            a.handle == handle
          end
        end

        def ensure_default_account
          accounts = Aptible::Api::Account.all(token: fetch_token)
          return accounts.first if accounts.count == 1

          fail Thor::Error, <<-ERR.gsub(/\s+/, ' ').strip
            Multiple accounts available, please specify with --account
          ERR
        end
      end
    end
  end
end
