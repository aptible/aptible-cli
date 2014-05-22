require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Operation
        POLL_INTERVAL = 1

        def poll_for_success(operation)
          puts 'Updating configuration and restarting app...'
          wait_for_completion operation
          return if operation.status == 'succeeded'
          fail Thor::Error, 'Operation failed: please check logs'
        end

        def wait_for_completion(operation)
          while %w(queued running).include? operation.status
            sleep 1
            operation.get
          end
        end
      end
    end
  end
end
