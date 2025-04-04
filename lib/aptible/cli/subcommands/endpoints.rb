require 'term/ansicolor'
require 'uri'

module Aptible
  module CLI
    module Subcommands
      module Endpoints
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::AppOrDatabase
            include Helpers::Vhost
            include Helpers::Telemetry

            database_create_flags = Helpers::Vhost::OptionSetBuilder.new do
              create!
              database!
            end

            desc 'endpoints:database:create DATABASE',
                 'Create a Database Endpoint'
            database_create_flags.declare_options(self)
            define_method 'endpoints:database:create' do |handle|
              telemetry(__method__, options.merge(handle: handle))

              database = ensure_database(options.merge(db: handle))
              service = database.service
              raise Thor::Error, 'Database is not provisioned' if service.nil?

              vhost = service.create_vhost!(
                type: 'tcp',
                platform: 'elb',
                **database_create_flags.prepare(database.account, options)
              )

              provision_vhost_and_explain(service, vhost)
            end

            database_modify_flags = Helpers::Vhost::OptionSetBuilder.new do
              database!
            end

            desc 'endpoints:database:modify --database DATABASE ' \
                 'ENDPOINT_HOSTNAME',
                 'Modify a Database Endpoint'
            database_modify_flags.declare_options(self)
            define_method 'endpoints:database:modify' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))

              database = ensure_database(options.merge(db: options[:database]))
              vhost = find_vhost(each_service(database), hostname)
              vhost.update!(**database_modify_flags.prepare(database.account,
                                                            options))
              provision_vhost_and_explain(vhost.service, vhost)
            end

            tcp_create_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              create!
              ports!
            end

            desc 'endpoints:tcp:create [--app APP] SERVICE',
                 'Create an App TCP Endpoint'
            tcp_create_flags.declare_options(self)
            define_method 'endpoints:tcp:create' do |type|
              telemetry(__method__, options.merge(type: type))

              create_app_vhost(
                tcp_create_flags, options, type,
                type: 'tcp', platform: 'elb'
              )
            end

            tcp_modify_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              ports!
            end

            desc 'endpoints:tcp:modify [--app APP] ENDPOINT_HOSTNAME',
                 'Modify an App TCP Endpoint'
            tcp_modify_flags.declare_options(self)
            define_method 'endpoints:tcp:modify' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))

              modify_app_vhost(tcp_modify_flags, options, hostname)
            end

            tls_create_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              create!
              ports!
              tls!
            end

            desc 'endpoints:tls:create [--app APP] SERVICE',
                 'Create an App TLS Endpoint'
            tls_create_flags.declare_options(self)
            define_method 'endpoints:tls:create' do |type|
              telemetry(__method__, options.merge(type: type))

              create_app_vhost(
                tls_create_flags, options, type,
                type: 'tls', platform: 'elb'
              )
            end

            tls_modify_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              ports!
              tls!
            end

            desc 'endpoints:tls:modify [--app APP] ENDPOINT_HOSTNAME',
                 'Modify an App TLS Endpoint'
            tls_modify_flags.declare_options(self)
            define_method 'endpoints:tls:modify' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))

              modify_app_vhost(tls_modify_flags, options, hostname)
            end

            grpc_create_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              create!
              port!
              tls!
            end

            desc 'endpoints:grpc:create [--app APP] SERVICE',
                 'Create an App gRPC Endpoint'
            grpc_create_flags.declare_options(self)
            define_method 'endpoints:grpc:create' do |type|
              telemetry(__method__, options.merge(type: type))

              create_app_vhost(
                grpc_create_flags, options, type,
                type: 'grpc', platform: 'elb'
              )
            end

            grpc_modify_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              port!
              tls!
            end

            desc 'endpoints:grpc:modify [--app APP] ENDPOINT_HOSTNAME',
                 'Modify an App gRPC Endpoint'
            grpc_modify_flags.declare_options(self)
            define_method 'endpoints:grpc:modify' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))

              modify_app_vhost(grpc_modify_flags, options, hostname)
            end

            https_create_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              create!
              port!
              tls!
            end

            desc 'endpoints:https:create [--app APP] SERVICE',
                 'Create an App HTTPS Endpoint'
            https_create_flags.declare_options(self)
            define_method 'endpoints:https:create' do |type|
              telemetry(__method__, options.merge(type: type))

              create_app_vhost(
                https_create_flags, options, type,
                type: 'http', platform: 'alb'
              )
            end

            https_modify_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              port!
              tls!
            end

            desc 'endpoints:https:modify [--app APP] ENDPOINT_HOSTNAME',
                 'Modify an App HTTPS Endpoint'
            https_modify_flags.declare_options(self)
            define_method 'endpoints:https:modify' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))
              modify_app_vhost(https_modify_flags, options, hostname)
            end

            desc 'endpoints:list [--app APP | --database DATABASE]',
                 'List Endpoints for an App or Database'
            app_or_database_options
            define_method 'endpoints:list' do
              telemetry(__method__, options)

              resource = ensure_app_or_database(options)

              Formatter.render(Renderer.current) do |root|
                root.list do |list|
                  each_service(resource) do |service|
                    service.each_vhost do |vhost|
                      list.object do |node|
                        ResourceFormatter.inject_vhost(node, vhost, service)
                      end
                    end
                  end
                end
              end
            end

            desc 'endpoints:deprovision [--app APP | --database DATABASE] ' \
                 'ENDPOINT_HOSTNAME', \
                 'Deprovision an App or Database Endpoint'
            app_or_database_options
            define_method 'endpoints:deprovision' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))

              resource = ensure_app_or_database(options)
              vhost = find_vhost(each_service(resource), hostname)
              op = vhost.create_operation!(type: 'deprovision')
              attach_to_operation_logs(op)
            end

            desc 'endpoints:renew [--app APP] ENDPOINT_HOSTNAME', \
                 'Renew an App Managed TLS Endpoint'
            long_desc <<-LONGDESC
              Use this command for the initial activation of an App Managed
              TLS Endpoint.

              WARNING: review the documentation on rate limits before using
              this command automatically
              (https://www.aptible.com/docs/core-concepts/apps/connecting-to-apps/app-endpoints/managed-tls#rate-limits).
            LONGDESC
            app_options
            define_method 'endpoints:renew' do |hostname|
              telemetry(__method__, options.merge(hostname: hostname))

              app = ensure_app(options)
              vhost = find_vhost(app.each_service, hostname)
              op = vhost.create_operation!(type: 'renew')
              attach_to_operation_logs(op)
            end

            no_commands do
              def create_app_vhost(flags, options, process_type, **attrs)
                service = ensure_service(options, process_type)
                vhost = service.create_vhost!(
                  **flags.prepare(service.account, options),
                  **attrs
                )
                provision_vhost_and_explain(service, vhost)
              end

              def modify_app_vhost(flags, options, hostname)
                app = ensure_app(options)
                vhost = find_vhost(each_service(app), hostname)
                vhost.update!(**flags.prepare(vhost.service.account, options))
                provision_vhost_and_explain(vhost.service, vhost)
              end
            end
          end
        end
      end
    end
  end
end
