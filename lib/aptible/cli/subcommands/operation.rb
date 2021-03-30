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

            desc 'operation:log OPERATION_ID',
                 'Follow log of a running operation'
            define_method 'operation:log' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              if %w(failed succeeded).include? o.status
                raise Thor::Error, "This operation has already #{o.status}. " \
                                  'Only currently running operations are '\
                                  'supported by this command at this time.'
              end

              m = "Streaming logs for #{prettify_operation(o)}..."
              CLI.logger.info m

              attach_to_operation_logs(o)
            end
          end
        end
      end
    end
  end
end
