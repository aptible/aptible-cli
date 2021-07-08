module Aptible
  module CLI
    module Subcommands
      module LogDrain
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Database
            include Helpers::LogDrain

            drain_flags = '--environment ENVIRONMENT ' \
                          '[--drain-apps true/false] ' \
                          '[--drain_databases true/false] ' \
                          '[--drain_ephemeral_sessions true/false] ' \
                          '[--drain_proxies true/false]'

            def self.drain_options
              option :drain_apps, default: true, type: :boolean
              option :drain_databases, default: true, type: :boolean
              option :drain_ephemeral_sessions, default: true, type: :boolean
              option :drain_proxies, default: true, type: :boolean
              option :environment
            end

            desc 'log_drain:list', 'List all Log Drains'
            option :environment
            define_method 'log_drain:list' do
              Formatter.render(Renderer.current) do |root|
                root.keyed_list('description') do |node|
                  scoped_environments(options).each do |account|
                    account.log_drains.each do |drain|
                      node.object do |n|
                        ResourceFormatter.inject_log_drain(n, drain, account)
                      end
                    end
                  end
                end
              end
            end

            desc 'log_drain:create:elasticsearch HANDLE '\
                 '--db DATABASE_HANDLE ' \
                 + drain_flags,
                 'Create an Elasticsearch Log Drain'
            drain_options
            option :db, type: :string
            option :pipeline, type: :string
            define_method 'log_drain:create:elasticsearch' do |handle|
              account = ensure_environment(options)
              database = ensure_database(options)

              opts = {
                handle: handle,
                database_id: database.id,
                logging_token: options[:pipeline],
                drain_apps: options[:drain_apps],
                drain_databases: options[:drain_databases],
                drain_ephemeral_sessions: options[:drain_ephemeral_sessions],
                drain_proxies: options[:drain_proxies],
                drain_type: :elasticsearch_database
              }

              create_log_drain(account, opts)
            end

            desc 'log_drain:create:datadog HANDLE ' \
                 '--url DATADOG_URL ' \
                 + drain_flags,
                 'Create a Datadog Log Drain'
            drain_options
            option :url, type: :string
            define_method 'log_drain:create:datadog' do |handle|
              msg = 'Must be in the format of ' \
                    '"https://http-intake.logs.datadoghq.com' \
                    '/v1/input/<DD_API_KEY>".'
              create_https_based_log_drain(handle, options, url_format_msg: msg)
            end

            desc 'log_drain:create:https HANDLE ' \
                 '--url URL ' \
                 + drain_flags,
                 'Create a HTTPS Drain'
            option :url, type: :string
            drain_options
            define_method 'log_drain:create:https' do |handle|
              create_https_based_log_drain(handle, options)
            end

            desc 'log_drain:create:sumologic HANDLE ' \
                 '--url SUMOLOGIC_URL ' \
                 + drain_flags,
                 'Create a Sumologic Drain'
            option :url, type: :string
            drain_options
            define_method 'log_drain:create:sumologic' do |handle|
              create_https_based_log_drain(handle, options)
            end

            desc 'log_drain:create:logdna HANDLE ' \
                 '--url LOGDNA_URL ' \
                 + drain_flags,
                 'Create a LogDNA Log Drain'
            option :url, type: :string
            drain_options
            define_method 'log_drain:create:logdna' do |handle|
              msg = 'Must be in the format of ' \
                    '"https://logs.logdna.com/aptible/ingest/<INGESTION KEY>".'
              create_https_based_log_drain(handle, options, url_format_msg: msg)
            end

            desc 'log_drain:create:papertrail HANDLE ' \
                 '--host PAPERTRAIL_HOST --port PAPERTRAIL_PORT ' \
                 + drain_flags,
                 'Create a Papertrail Log Drain'
            option :host, type: :string
            option :port, type: :string
            drain_options
            define_method 'log_drain:create:papertrail' do |handle|
              create_syslog_based_log_drain(handle, options)
            end

            desc 'log_drain:create:syslog HANDLE ' \
                 '--host SYSLOG_HOST --port SYSLOG_PORT ' \
                 '[--token TOKEN] ' \
                 + drain_flags,
                 'Create a Papertrail Log Drain'
            option :host, type: :string
            option :port, type: :string
            option :token, type: :string
            drain_options
            define_method 'log_drain:create:syslog' do |handle|
              create_syslog_based_log_drain(handle, options)
            end

            desc 'log_drain:deprovision HANDLE --environment ENVIRONMENT',
                 'Deprovisions a log drain'
            option :environment
            define_method 'log_drain:deprovision' do |handle|
              account = ensure_environment(options)
              drain = ensure_log_drain(account, handle)
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
