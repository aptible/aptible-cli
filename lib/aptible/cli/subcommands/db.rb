module Aptible
  module CLI
    module Subcommands
      module DB
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::Token

            desc 'db:create HANDLE', 'Create a new database'
            option :type, default: 'postgresql'
            option :size, default: 10
            option :account
            define_method 'db:create' do |handle|
              account = ensure_account(options)
              database = account.create_database(handle: handle,
                                                 type: options[:type])

              if database.errors.any?
                fail Thor::Error, database.errors.full_messages.first
              else
                op = database.create_operation(type: 'provision',
                                               disk_size: options[:size])
                poll_for_success(op)
                say database.reload.connection_url
              end
            end

            desc 'db:clone SOURCE DEST', 'Clone a database to create a new one'
            define_method 'db:clone' do |source_handle, dest_handle|
              dest = clone_database(source_handle, dest_handle)
              say dest.connection_url
            end

            desc 'db:dump HANDLE', 'Dump a remote database to file'
            define_method 'db:dump' do |handle|
              dump_database( handle )
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :port, type: :numeric
            define_method 'db:tunnel' do |handle|
              database = database_from_handle(handle)
              local_port = options[:port] || random_local_port
              puts "Creating tunnel at localhost:#{local_port}..."
              establish_connection(database, local_port)
            end

            desc 'db:anonymize HANDLE SQL_FILE', 'Clone a database, anonymize the clone with the given sql file, and then downloads it'
            define_method 'db:anonymize' do |source_handle, sql_path|
              dest_handle = "#{source_handle}-anonymized-#{Time.now.to_i}"
              dest = clone_database(source_handle, dest_handle)

              execute_local_tunnel(dest_handle) do |url|
                puts "Executing #{sql_path} against #{dest_handle}"
                `psql #{url} < #{sql_path}`
              end

              dump_database( dest_handle )
            end

            private

            def establish_connection(database, local_port)
              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_DATABASE'] = database.handle

              remote_port = claim_remote_port(database)
              ENV['TUNNEL_PORT'] = remote_port

              tunnel_args = "-L #{local_port}:localhost:#{remote_port}"
              command = "ssh #{tunnel_args} #{common_ssh_args(database)}"
              Kernel.exec(command)
            end

            def database_from_handle(handle, options = {:postgres_only => false})
              database = Aptible::Api::Database.all(token: fetch_token).find do |a|
                a.handle == handle
              end

              unless database
                fail Thor::Error, "Could not find database #{handle}"
              end

              if options[:postgres_only] && database.type != 'postgresql'
                fail Thor::Error, 'This command only works for PostgreSQL'
              end

              return database
            end

            def clone_database(source_handle, dest_handle)
              puts "Cloning #{source_handle} to #{dest_handle}"

              source = database_from_handle(source_handle)
              op = source.create_operation(type: 'clone', handle: dest_handle)
              poll_for_success(op)

              return database_from_handle(dest_handle)
            end

            def dump_database(handle)
              execute_local_tunnel(handle) do |url|
                filename = "#{handle}.dump"
                puts "Dumping to #{filename}"
                `pg_dump #{url} > #{filename}`
              end
            end

            # Creates a local tunnel and yields the url to it

            def execute_local_tunnel(handle)
              begin
                database = database_from_handle(handle, :postgres_only => true)

                local_port = random_local_port
                pid = fork { establish_connection(database, local_port) }

                # TODO: Better test for connection readiness
                sleep 10

                yield "postgresql://aptible:#{database.passphrase}@localhost:#{local_port}/db"
              ensure
                Process.kill('HUP', pid) if pid
              end
            end

            def random_local_port
              # Allocate a dummy server to discover an available port
              dummy = TCPServer.new('127.0.0.1', 0)
              port = dummy.addr[1]
              dummy.close
              port
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
