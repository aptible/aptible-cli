require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Operation
        include Helpers::Ssh

        POLL_INTERVAL = 1

        def poll_for_success(operation)
          wait_for_completion operation
          return if operation.status == 'succeeded'

          fail Thor::Error, "Operation ##{operation.id} failed."
        end

        def wait_for_completion(operation)
          while %w(queued running).include? operation.status
            sleep 1
            operation.get
          end
        end

        def attach_to_operation_logs(operation)
          ENV['ACCESS_TOKEN'] = fetch_token
          ENV['APTIBLE_OPERATION'] = operation.id.to_s
          ENV['APTIBLE_CLI_COMMAND'] = 'oplog'

          cmd = dumptruck_ssh_command(operation.resource.account) + [
            '-o', 'SendEnv=ACCESS_TOKEN',
            '-o', 'SendEnv=APTIBLE_OPERATION',
            '-o', 'SendEnv=APTIBLE_CLI_COMMAND'
          ]

          success = Kernel.system(*cmd)

          # If Dumptruck is down, fall back to polling for success. If the
          # operation failed, poll_for_success will immediately fall through to
          # the error message.
          poll_for_success(operation) unless success
        end
      end
    end
  end
end
