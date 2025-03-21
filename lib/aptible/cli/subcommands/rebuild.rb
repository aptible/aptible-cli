module Aptible
  module CLI
    module Subcommands
      module Rebuild
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App
            include Helpers::Telemetry

            desc 'rebuild', 'Rebuild an app, and restart its services'
            app_options
            def rebuild
              telemetry(__method__, options)

              app = ensure_app(options)
              operation = app.create_operation!(type: 'rebuild')
              CLI.logger.info 'Rebuilding app...'
              attach_to_operation_logs(operation)
            end
          end
        end
      end
    end
  end
end
