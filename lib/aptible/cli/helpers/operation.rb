require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Operation
        POLL_INTERVAL = 1

        def poll_for_success(operation)
          wait_for_completion operation
          return if operation.status == 'succeeded'
          fail Thor::Error,
               'Operation failed. Please contact support@aptible.com'
        end

        def wait_for_completion(operation)
          while %w(queued running).include? operation.status
            sleep 1
            operation.get
          end
        end

        def attach_to_operation_logs(operation)
          host = operation.resource.account.bastion_host
          port = operation.resource.account.dumptruck_port

          set_env('ACCESS_TOKEN', fetch_token)
          set_env('APTIBLE_OPERATION', operation.id.to_s)
          set_env('APTIBLE_CLI_COMMAND', 'oplog')

          opts = " -o 'SendEnv=*' -o StrictHostKeyChecking=no " \
                 '-o UserKnownHostsFile=/dev/null -o LogLevel=quiet'
          Kernel.exec "ssh #{opts} -p #{port} root@#{host}"
        end
      end
    end
  end
end
