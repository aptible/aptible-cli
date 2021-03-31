module Aptible
  module CLI
    module Subcommands
      module Operation
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Operation
            include Helpers::AppOrDatabase

            desc 'operation:cancel OPERATION_ID', 'Cancel a running operation'
            define_method 'operation:cancel' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              m = "Requesting cancellation on #{prettify_operation(o)}..."
              CLI.logger.info m
              o.update!(cancelled: true)
            end

            desc 'operation:list [--app APP | --database DATABASE]',
                 'List running or recent operations for an App or Database'
            option :max_age,
                   default: '1w',
                   desc: 'Limit operations returned '\
                         '(example usage: 1w, 1y, etc.)'
            app_or_database_options
            define_method 'operation:list' do
              age = ChronicDuration.parse(options[:max_age])
              raise Thor::Error, "Invalid age: #{options[:max_age]}" if age.nil?
              min_created_at = Time.now - age

              resource = ensure_app_or_database(options)

              m = "Operations for #{resource.handle}: "\
                  "#{resource.operations.count}"
              CLI.logger.info m

              Formatter.render(Renderer.current) do |root|
                root.keyed_list('description') do |node|
                  all_operations = resource.operations
                  # TODO: make aptible-api-ruby include
                  # app service and vhost operations?
                  all_operations.each do |op|
                    created_at = op.created_at
                    break if created_at < min_created_at
                    node.object do |n|
                      ResourceFormatter.inject_operation(n, op)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
