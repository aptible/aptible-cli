module Aptible
  module CLI
    module Subcommands
      module MetricDrain
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Database
            include Helpers::MetricDrain

            desc 'metric_drain:list', 'List all Metric Drains'
            option :environment
            define_method 'metric_drain:list' do
              Formatter.render(Renderer.current) do |root|
                root.keyed_list('description') do |node|
                  scoped_environments(options).each do |account|
                    account.metric_drains.each do |drain|
                      node.object do |n|
                        ResourceFormatter.inject_metric_drain(n, drain, account)
                      end
                    end
                  end
                end
              end
            end

            desc 'metric_drain:create:influxdb HANDLE '\
                 '--db DATABASE_HANDLE --environment ENVIRONMENT',
                 'Create an InfluxDB Metric Drain'
            option :db, type: :string
            option :environment

            define_method 'metric_drain:create:influxdb' do |handle|
              account = ensure_environment(options)
              database = ensure_database(options)

              opts = {
                handle: handle,
                database_id: database.id,
                drain_type: :influxdb_database
              }

              create_metric_drain(account, opts)
            end

            desc 'metric_drain:create:influxdb:custom HANDLE '\
                 '--username USERNAME --password PASSWORD ' \
                 '--url URL_INCLUDING_PORT',
                 'Create an InfluxDB Metric Drain'
            option :db, type: :string
            option :username, type: :string
            option :password, type: :string
            option :url, type: :string
            option :db, type: :string
            option :environment
            define_method 'metric_drain:create:influxdb:custom' do |handle|
              account = ensure_environment(options)

              config = {
                address: options[:url],
                username: options[:username],
                password: options[:password],
                database: options[:db]
              }
              opts = {
                handle: handle,
                drain_configuration: config,
                drain_type: :influxdb
              }

              create_metric_drain(account, opts)
            end

            desc 'metric_drain:create:datadog HANDLE '\
                 '--api_key DATADOG_API_KEY --environment ENVIRONMENT',
                 'Create a Datadog Metric Drain'
            option :api_key, type: :string
            option :custom_url, type: :string
            option :environment
            define_method 'metric_drain:create:datadog' do |handle|
              account = ensure_environment(options)

              config = {
                api_key: options[:api_key]
              }
              unless options[:custom_url].nil?
                config[:series_url] = options[:custom_url]
              end
              opts = {
                handle: handle,
                drain_type: :datadog,
                drain_configuration: config
              }

              create_metric_drain(account, opts)
            end

            desc 'metric_drain:deprovision HANDLE --environment ENVIRONMENT',
                 'Deprovisions a Metric Drain'
            option :environment
            define_method 'metric_drain:deprovision' do |handle|
              account = ensure_environment(options)
              drain = ensure_metric_drain(account, handle)
              op = drain.create_operation(type: :deprovision)
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
