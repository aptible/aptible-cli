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

            desc 'services:settings SERVICE'\
                   ' [--force-zero-downtime|--no-force-zero-downtime]'\
                   ' [--simple-health-check|--no-simple-health-check]',
                 'Modifies the zero-downtime deploy setting for a service'
            app_options
            option :force_zero_downtime,
                   type: :boolean, default: false,
                   desc: 'Force zero downtime deployments.'\
                   ' Has no effect if service has an associated Endpoint'
            option :simple_health_check,
                   type: :boolean, default: false,
                   desc: 'Use a simple uptime healthcheck during deployments'
            define_method 'services:settings' do |service|
              service = ensure_service(options, service)
              updates = {}
              updates[:force_zero_downtime] =
                options[:force_zero_downtime] if options[:force_zero_downtime]
              updates[:naive_health_check] =
                options[:simple_health_check] if options[:simple_health_check]

              service.update!(**updates) if updates.any?
            end
          end
        end
      end
    end
  end
end
