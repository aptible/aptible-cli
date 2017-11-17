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

              Formatter.render(Renderer.current) do |root|
                root.list do |list|
                  app.each_service do |service|
                    list.object do |node|
                      ResourceFormatter.inject_service(node, service, app)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
