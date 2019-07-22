module Aptible
  module CLI
    module Subcommands
      module Restart
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'restart', 'Restart all services associated with an app'
            option :simulate_oom,
                   type: :boolean,
                   desc: 'Add this flag to simulate an OOM restart and test ' \
                         "your app's response (not recommended on production " \
                         'apps).'
            option :force,
                   type: :boolean,
                   desc: 'Add this flag to use --simulate-oom in a ' \
                         'production environment, which is not allowed by ' \
                         'default.'
            app_options
            def restart
              app = ensure_app(options)
              type = 'restart'

              if options[:simulate_oom]
                type = 'captain_comeback_restart'

                if app.account.type == 'production' && !options[:force]
                  e = 'This operation is designed for test purposes only, ' \
                      "but #{app.handle} is deployed in a production " \
                      'environment. Are you sure you want to do this? If ' \
                      'so, use the --force flag.'
                  raise Thor::Error, e
                end
              end

              operation = app.create_operation!(type: type)
              CLI.logger.info 'Restarting app...'
              attach_to_operation_logs(operation)
            end
          end
        end
      end
    end
  end
end
