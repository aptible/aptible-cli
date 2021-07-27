module Aptible
  module CLI
    module Subcommands
      module Apps
        def self.included(thor)
          thor.class_eval do
            include Helpers::App
            include Helpers::Environment
            include Helpers::Token

            desc 'apps', 'List all applications'
            option :environment
            def apps
              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'handle'
                ) do |node|
                  scoped_environments(options).each do |account|
                    account.each_app do |app|
                      node.object do |n|
                        ResourceFormatter.inject_app(n, app, account)
                      end
                    end
                  end
                end
              end
            end

            desc 'apps:create HANDLE', 'Create a new application'
            option :environment
            define_method 'apps:create' do |handle|
              environment = ensure_environment(options)
              app = environment.create_app(handle: handle)

              if app.errors.any?
                raise Thor::Error, app.errors.full_messages.first
              else
                CLI.logger.info "App #{handle} created!"

                Formatter.render(Renderer.current) do |root|
                  root.object do |o|
                    o.value('git_remote', app.git_repo)
                  end
                end
              end
            end

            desc 'apps:scale SERVICE ' \
                 '[--container-count COUNT] [--container-size SIZE_MB]',
                 'Scale a service'
            app_options
            option :container_count, type: :numeric
            option :container_size, type: :numeric
            define_method 'apps:scale' do |type|
              service = ensure_service(options, type)

              container_count = options[:container_count]
              container_size = options[:container_size]

              if options[:size]
                m = 'You have used the "--size" option to specify a container '\
                    'size. This abiguous option has been removed.'\
                    'Please use the "--container-size" option, instead.'
                raise Thor::Error, m
              end

              if container_count.nil? && container_size.nil?
                raise Thor::Error,
                      'Provide at least --container-count or --container-size'
              end

              # We don't validate any parameters here: API will do that for us.
              opts = { type: 'scale' }
              opts[:container_count] = container_count if container_count
              opts[:container_size] = container_size if container_size

              op = service.create_operation!(opts)
              attach_to_operation_logs(op)
            end

            desc 'apps:deprovision', 'Deprovision an app'
            app_options
            define_method 'apps:deprovision' do
              app = ensure_app(options)
              CLI.logger.info "Deprovisioning #{app.handle}..."
              op = app.create_operation!(type: 'deprovision')
              begin
                attach_to_operation_logs(op)
              rescue HyperResource::ClientError => e
                # A 404 here means that the operation completed successfully,
                # and was removed faster than attach_to_operation_logs
                # could attach to the logs.
                raise if e.response.status != 404
              end
            end
          end
        end
      end
    end
  end
end
