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
              fail "Operation ##{operation_id} not found" if o.nil?

              puts "Requesting cancellation on #{prettify_operation(o)}..."
              o.update!(cancelled: true)
            end
          end
        end
      end
    end
  end
end
