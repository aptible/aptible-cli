module Aptible
  module CLI
    module Subcommands
      module Restart
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'restart', 'Restart all services associated with an app'
            option :app
            option :remote, aliases: '-r'
            def restart
              app = ensure_app(options)
              operation = app.create_operation(type: 'restart')
              puts 'Restarting app...'
              attach_to_operation_logs(operation)
            end
          end
        end
      end
    end
  end
end
