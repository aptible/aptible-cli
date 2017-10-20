module Aptible
  module CLI
    module Subcommands
      module Services
        def self.included(thor)
          thor.class_eval do
            include Helpers::App

            desc 'services', 'List Services for an App'
            app_options
            def services
              app = ensure_app(options)

              first = true
              app.each_service do |service|
                say '' unless first
                first = false

                say "Service: #{service.process_type}"
                say "Command: #{service.command || 'CMD'}"
                say "Container Count: #{service.container_count}"
                say "Container Size: #{service.container_memory_limit_mb}"
              end
            end
          end
        end
      end
    end
  end
end
