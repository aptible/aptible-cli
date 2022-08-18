module Aptible
  module CLI
    module Subcommands
      module Operation
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Operation

            desc 'operation:cancel OPERATION_ID', 'Cancel a running operation'
            define_method 'operation:cancel' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              m = "Requesting cancellation on #{prettify_operation(o)}..."
              CLI.logger.info m
              o.update!(cancelled: true)
            end

            desc 'operation:logs OPERATION_ID', 'View logs for a given operation'
            define_method 'operation:logs' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              # if operation is not complete, send back a simple message saying its not ready yet
              # TODO - check status enums
              unless %w(succeeded failed finished).include? o.status
                # TODO - maybe we should include a copy-pasteable alternate command to view it while it's in-progress?
                e = "Unable to retrieve operation logs. You can view these logs when the operation is complete."
                raise Thor::Error, e
              end

              m = "Requesting operation logs for #{prettify_operation(o)}..."
              CLI.logger.info m
              operation_logs(o)
            end
          end
        end
      end
    end
  end
end
