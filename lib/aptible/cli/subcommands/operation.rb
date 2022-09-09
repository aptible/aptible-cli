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

            desc 'operation:follow OPERATION_ID',
                 'Follow logs of a running operation'
            define_method 'operation:follow' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              if %w(failed succeeded).include? o.status
                raise Thor::Error, "This operation has already #{o.status}. " \
                                   'Run the following command to retrieve ' \
                                   "the operation's logs:\n" \
                                   "aptible operation:logs #{o.id}"
              end

              CLI.logger.info "Streaming logs for #{prettify_operation(o)}..."

              attach_to_operation_logs(o)
            end

            desc 'operation:logs OPERATION_ID', 'View logs for given operation'
            define_method 'operation:logs' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              unless %w(succeeded failed).include? o.status
                e = 'Error - You can view the logs when operation is complete.'
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
