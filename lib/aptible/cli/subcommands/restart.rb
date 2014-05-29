module Aptible
  module CLI
    module Subcommands
      module Restart
        # rubocop:disable MethodLength
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'restart', 'Restart all services associated with an app'
            option :app
            def restart
              app = ensure_app(options)
              operation = app.create_operation(type: 'restart')
              puts 'Restarting app...'
              poll_for_success(operation)
            end
          end
        end
        # rubocop:enable MethodLength
      end
    end
  end
end
