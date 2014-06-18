module Aptible
  module CLI
    module Subcommands
      module Apps
        # rubocop:disable MethodLength
        def self.included(thor)
          thor.class_eval do
            include Helpers::Account

            desc 'apps:create HANDLE', 'Create a new application'
            option :account
            define_method 'apps:create' do |handle|
              account = ensure_account(options)
              app = account.create_app(handle: handle)

              if app.errors.any?
                fail app.errors.full_messages.first
              else
                say "App #{handle} created!"
              end
            end
          end
        end
        # rubocop:enable MethodLength
      end
    end
  end
end
