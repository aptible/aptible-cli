module Aptible
  module CLI
    module Helpers
      module LogDrain
        include Helpers::Token

        def create_log_drain(account, drain_opts)
          drain = account.create_log_drain!(drain_opts)
          op = drain.create_operation(type: :provision)

          if op.errors.any?
            # NOTE: If we fail to provision the log drain, we should try and
            # clean it up immediately.
            drain.create_operation(type: :deprovision)
            raise Thor::Error, op.errors.full_messages.first
          end

          attach_to_operation_logs(op)
        end

        def create_https_based_log_drain(handle, options, url_format_msg: nil)
          account = ensure_environment(options)
          url = ensure_url(options, url_format_msg: url_format_msg)

          opts = {
            handle: handle,
            url: url,
            drain_apps: options[:drain_apps],
            drain_databases: options[:drain_databases],
            drain_ephemeral_sessions: options[:drain_ephemeral_sessions],
            drain_proxies: options[:drain_proxies],
            drain_type: :https_post
          }
          create_log_drain(account, opts)
        end

        def create_syslog_based_log_drain(handle, options)
          account = ensure_environment(options)

          opts = {
            handle: handle,
            drain_host: options[:host],
            drain_port: options[:port],
            logging_token: options[:token],
            drain_apps: options[:drain_apps],
            drain_databases: options[:drain_databases],
            drain_ephemeral_sessions: options[:drain_ephemeral_sessions],
            drain_proxies: options[:drain_proxies],
            drain_type: :syslog_tls_tcp
          }
          create_log_drain(account, opts)
        end

        def ensure_url(options, url_format_msg: nil)
          msg = '--url is required.'
          msg = "#{msg} #{url_format_msg}" unless url_format_msg.nil?

          url = options[:url]
          raise Thor::Error, msg if url.nil?

          # API already does url validation, so I'm not going
          # to duplicate that logic here, even if it would
          # get us an error faster
          url
        end

        def ensure_log_drain(account, handle)
          drains = account.log_drains.select { |d| d.handle == handle }

          if drains.empty?
            raise Thor::Error, "No drain found with handle #{handle}"
          end

          # Log Drain handles are globally unique, so this is excessive
          unless drains.length == 1
            raise Thor::Error, "#{drains.length} drains found with handle "\
                               "#{handle}"
          end

          drains.first
        end
      end
    end
  end
end
