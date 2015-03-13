module Aptible
  module CLI
    module Subcommands
      module Rebuild
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'rebuild', 'Rebuild an app, and restart its services'
            option :app
            option :remote, aliases: '-r'
            def rebuild
              app = ensure_app(options)
              operation = app.create_operation(type: 'rebuild')
              puts 'Rebuilding app...'
              poll_for_success(operation)
            end
          end
        end
      end
    end
  end
end
