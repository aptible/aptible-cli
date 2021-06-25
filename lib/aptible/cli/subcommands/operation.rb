module Aptible
  module CLI
    module Subcommands
      module Operation
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Operation
            include Helpers::AppOrDatabaseOrEnvironment

            desc 'operation:cancel OPERATION_ID', 'Cancel a running operation'
            define_method 'operation:cancel' do |operation_id|
              o = Aptible::Api::Operation.find(operation_id, token: fetch_token)
              raise "Operation ##{operation_id} not found" if o.nil?

              m = "Requesting cancellation on #{prettify_operation(o)}..."
              CLI.logger.info m
              o.update!(cancelled: true)
            end

            desc 'operation:list [--app APP | --database DATABASE |' \
                 ' --environment ENVIRONMENT ]',
                 'List running or recent operations for an App, Database,' \
                 ' or Environment'
            option :max_age,
                   default: '1w',
                   desc: 'Limit operations returned '\
                         '(example usage: 1w, 1y, etc.)'
            app_or_database_options
            define_method 'operation:list' do
              age = ChronicDuration.parse(options[:max_age])
              raise Thor::Error, "Invalid age: #{options[:max_age]}" if age.nil?
              min_created_at = Time.now - age

              resource = ensure_app_or_database_or_environment(options)

              Formatter.render(Renderer.current) do |root|
                root.keyed_list('description') do |node|
                  all_operations = resource.operations

                  if resource.is_a?(Aptible::Api::App)
                    resource.services.each do |s|
                      all_operations + s.operations
                    end
                    resource.vhosts.each do |v|
                      all_operations + v.operations
                    end
                    # Configurations?
                    # Image scan?
                  elsif resource.is_a?(Aptible::Api::Database)
                    # Backups?
                    # DatabaseCredential
                    resource.database_credentials.each do |c|
                      all_operations + c.operations
                    end
                    resource.service.vhosts.each do |v|
                      all_operations + v.operations
                    end
                  elsif resource.is_a?(Aptible::Api::Account)
                    puts "This many ops: #{resource.operations.count}"
                  end

                  # all_operations.order(id: :desc)
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
