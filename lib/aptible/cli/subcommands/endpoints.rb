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

            database_flags = Helpers::Vhost::OptionSetBuilder.new do
              database!
            end

            desc 'endpoints:database:create DATABASE',
                 'Create a Database Endpoint'
            database_flags.declare_options(self)
            define_method 'endpoints:database:create' do |handle|
              database = ensure_database(options.merge(db: handle))
              service = database.service
              raise Thor::Error, 'Database is not provisioned' if service.nil?

              vhost = service.create_vhost!(
                type: 'tcp',
                platform: 'elb',
                **database_flags.prepare(database.account, options)
              )

              provision_vhost_and_explain(service, vhost)
            end

            tcp_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              ports!
            end

            desc 'endpoints:tcp:create [--app APP] SERVICE',
                 'Create an App TCP Endpoint'
            tcp_flags.declare_options(self)
            define_method 'endpoints:tcp:create' do |type|
              service = ensure_service(options, type)

              vhost = service.create_vhost!(
                type: 'tcp',
                platform: 'elb',
                **tcp_flags.prepare(service.account, options)
              )

              provision_vhost_and_explain(service, vhost)
            end

            tls_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              ports!
              tls!
            end

            desc 'endpoints:tls:create [--app APP] SERVICE',
                 'Create an App TLS Endpoint'
            tls_flags.declare_options(self)
            define_method 'endpoints:tls:create' do |type|
              service = ensure_service(options, type)

              vhost = service.create_vhost!(
                type: 'tls',
                platform: 'elb',
                **tls_flags.prepare(service.account, options)
              )

              provision_vhost_and_explain(service, vhost)
            end

            https_flags = Helpers::Vhost::OptionSetBuilder.new do
              app!
              port!
              tls!
            end

            desc 'endpoints:https:create [--app APP] SERVICE',
                 'Create an App HTTPS Endpoint'
            https_flags.declare_options(self)
            define_method 'endpoints:https:create' do |type|
              service = ensure_service(options, type)

              vhost = service.create_vhost!(
                type: 'http',
                platform: 'alb',
                **https_flags.prepare(service.account, options)
              )

              provision_vhost_and_explain(service, vhost)
            end

            desc 'endpoints:list [--app APP | --database DATABASE]',
                 'List Endpoints for an App or Database'
            app_or_database_options
            define_method 'endpoints:list' do
              resource = ensure_app_or_database(options)

              first = true
              each_vhost(resource) do |service|
                service.each_vhost do |vhost|
                  say '' unless first
                  first = false
                  explain_vhost(service, vhost)
                end
              end
            end

            desc 'endpoints:deprovision [--app APP | --database DATABASE] ' \
                 'ENDPOINT_HOSTNAME', \
                 'Deprovision an App or Database Endpoint'
            app_or_database_options
            define_method 'endpoints:deprovision' do |hostname|
              resource = ensure_app_or_database(options)
              vhost = find_vhost(each_vhost(resource), hostname)
              op = vhost.create_operation!(type: 'deprovision')
              attach_to_operation_logs(op)
            end

            desc 'endpoints:renew [--app APP] ENDPOINT_HOSTNAME', \
                 'Renew an App Managed TLS Endpoint'
            app_options
            define_method 'endpoints:renew' do |hostname|
              app = ensure_app(options)
              vhost = find_vhost(app.each_service, hostname)
              op = vhost.create_operation!(type: 'renew')
              attach_to_operation_logs(op)
            end
          end

          # TODO: in the longer term once we have a good API representation for
          # it, we should include methods to update VHOSTs without having to
          # deprovison them or use the Dashboard.
        end
      end
    end
  end
end
