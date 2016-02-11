require 'term/ansicolor'

module Aptible
  module CLI
    module Subcommands
      module DB
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
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
              environment = ensure_environment(options)
              dest = clone_database(source_handle, dest_handle, environment)
              say dest.connection_url
            end

            desc 'db:dump HANDLE', 'Dump a remote database to file'
            option :environment
            define_method 'db:dump' do |handle|
              environment = ensure_environment(options)
              dump_database(handle, environment)
            end

            desc 'db:execute HANDLE SQL_FILE', 'Executes sql against a database'
            option :environment
            define_method 'db:execute' do |handle, sql_path|
              environment = ensure_environment(options)
              execute_local_tunnel(handle, environment) do |url|
                say "Executing #{sql_path} against #{handle}"
                `psql #{url} < #{sql_path}`
              end
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :environment
            option :port, type: :numeric
            define_method 'db:tunnel' do |handle|
              environment = ensure_environment(options)
              database = database_from_handle(handle, environment)
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
              environment = ensure_environment(options)
              database = database_from_handle(handle, environment)
              say "Deprovisioning #{handle}..."
              database.update!(status: 'deprovisioned')
              database.create_operation!(type: 'deprovision')
            end

            private

            def present_environment_databases(environment)
              say "=== #{environment.handle}"
              environment.databases.each { |db| say db.handle }
              say ''
            end

            def establish_connection(database, local_port)
              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_DATABASE'] = database.handle

              remote_port = claim_remote_port(database)
              ENV['TUNNEL_PORT'] = remote_port

              tunnel_args = "-L #{local_port}:localhost:#{remote_port}"
              command = "ssh #{tunnel_args} #{common_ssh_args(database)}"
              Kernel.exec(command)
            end

            def database_from_handle(handle,
                                     environment,
                                     options = { postgres_only: false })
              all = environment.databases
              database = all.find { |a|  a.handle == handle }

              unless database
                fail Thor::Error, "Could not find database #{handle}"
              end

              if options[:postgres_only] && database.type != 'postgresql'
                fail Thor::Error, 'This command only works for PostgreSQL'
              end

              database
            end

            def clone_database(source_handle, dest_handle, environment)
              source = database_from_handle(source_handle, environment)
              op = source.create_operation(type: 'clone', handle: dest_handle)
              poll_for_success(op)

              database_from_handle(dest_handle)
            end

            def dump_database(handle, environment)
              execute_local_tunnel(handle, environment) do |url|
                filename = "#{handle}.dump"
                say "Dumping to #{filename}"
                `pg_dump #{url} > #{filename}`
              end
            end

            # Creates a local tunnel and yields the url to it

            def execute_local_tunnel(handle, environment)
              database = database_from_handle(handle,
                                              environment,
                                              postgres_only: true)

              local_port = random_local_port
              pid = fork { establish_connection(database, local_port) }

              # TODO: Better test for connection readiness
              sleep 10

              auth = "aptible:#{database.passphrase}"
              host = "localhost:#{local_port}"
              yield "postgresql://#{auth}@#{host}/db"
            ensure
              Process.kill('HUP', pid) if pid
            end

            def random_local_port
              # Allocate a dummy server to discover an available port
              dummy = TCPServer.new('127.0.0.1', 0)
              port = dummy.addr[1]
              dummy.close
              port
            end

            def local_url(database, local_port)
              remote_url = database.connection_url
              uri = URI.parse(remote_url)

              "#{uri.scheme}://#{uri.user}:#{uri.password}@" \
              "127.0.0.1:#{local_port}#{uri.path}"
            end

            def claim_remote_port(database)
              ENV['ACCESS_TOKEN'] = fetch_token

              `ssh #{common_ssh_args(database)} 2>/dev/null`.chomp
            end

            def common_ssh_args(database)
              host = database.account.bastion_host
              port = database.account.bastion_port

              opts = " -o 'SendEnv=*' -o StrictHostKeyChecking=no " \
                     '-o UserKnownHostsFile=/dev/null'
              connection_args = "-p #{port} root@#{host}"
              "#{opts} #{connection_args}"
            end
          end
        end
      end
    end
  end
end
