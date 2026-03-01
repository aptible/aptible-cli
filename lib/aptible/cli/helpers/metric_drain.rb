module Aptible
  module CLI
    module Helpers
      module MetricDrain
        include Helpers::Token

        def create_metric_drain(account, drain_opts)
          drain = account.create_metric_drain!(drain_opts)
          op = drain.create_operation(type: :provision)

          if op.errors.any?
            # NOTE: If we fail to provision the log drain, we should try and
            # clean it up immediately.
            drain.create_operation(type: :deprovision)
            raise Thor::Error, op.errors.full_messages.first
          end

          attach_to_operation_logs(op)
        end

        def ensure_metric_drain(account, handle)
          account = with_sensitive(account)
          drains = account.metric_drains.select { |d| d.handle == handle }

          if drains.empty?
            raise Thor::Error, "No drain found with handle #{handle}"
          end

          # Metric Drain handles are globally unique, so this is excessive
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
