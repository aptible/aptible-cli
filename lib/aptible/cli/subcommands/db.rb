require 'term/ansicolor'

module Aptible
  module CLI
    module Subcommands
      module DB
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::Database
            include Helpers::Token
            include Term::ANSIColor

            desc 'db:list', 'List all databases'
            option :environment
            define_method 'db:list' do
              scoped_environments(options).each do |env|
                present_environment_databases(env)
              end
            end

            desc 'db:create HANDLE', 'Create a new database'
            option :type, default: 'postgresql'
            option :size, default: 10
            option :environment
            define_method 'db:create' do |handle|
              environment = ensure_environment(options)
              database = environment.create_database(handle: handle,
                                                     type: options[:type])

              if database.errors.any?
                fail Thor::Error, database.errors.full_messages.first
              else
                op = database.create_operation(type: 'provision',
                                               disk_size: options[:size])
                attach_to_operation_logs(op)
                say database.reload.connection_url
              end
            end

            desc 'db:clone SOURCE DEST', 'Clone a database to create a new one'
            option :environment
            define_method 'db:clone' do |source_handle, dest_handle|
              source = ensure_database(options.merge(db: source_handle))
              dest = clone_database(source, dest_handle)
              say dest.connection_url
            end

            desc 'db:dump HANDLE', 'Dump a remote database to file'
            option :environment
            define_method 'db:dump' do |handle|
              database = ensure_database(options.merge(db: handle))
              dump_database(database)
            end

            desc 'db:execute HANDLE SQL_FILE', 'Executes sql against a database'
            option :environment
            define_method 'db:execute' do |handle, sql_path|
              database = ensure_database(options.merge(db: handle))
              execute_local_tunnel(database) do |url|
                say "Executing #{sql_path} against #{database.handle}"
                `psql #{url} < #{sql_path}`
              end
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :environment
            option :port, type: :numeric
            define_method 'db:tunnel' do |handle|
              database = ensure_database(options.merge(db: handle))
              local_port = options[:port] || random_local_port

              say 'Creating tunnel...', :green
              say "Connect at #{local_url(database, local_port)}", :green

              uri = URI(local_url(database, local_port))
              db = uri.path.gsub(%r{^/}, '')
              say 'Or, use the following arguments:', :green
              say("* Host: #{uri.host}", :green)
              say("* Port: #{uri.port}", :green)
              say("* Username: #{uri.user}", :green) unless uri.user.empty?
              say("* Password: #{uri.password}", :green)
              say("* Database: #{db}", :green) unless db.empty?
              establish_connection(database, local_port)
            end

            desc 'db:deprovision HANDLE', 'Deprovision a database'
            option :environment
            define_method 'db:deprovision' do |handle|
              database = ensure_database(options.merge(db: handle))
              say "Deprovisioning #{database.handle}..."
              database.update!(status: 'deprovisioned')
              database.create_operation!(type: 'deprovision')
            end
          end
        end
      end
    end
  end
end
