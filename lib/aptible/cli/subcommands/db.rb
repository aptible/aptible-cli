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
            option :account
            define_method 'db:list' do
              appropriate_accounts(options).each do |account|
                present_account_databases(account)
              end
            end

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
              dump_database(handle)
            end

            desc 'db:execute HANDLE SQL_FILE', 'Executes sql against a database'
            define_method 'db:execute' do |handle, sql_path|
              execute_local_tunnel(handle) do |url|
                say "Executing #{sql_path} against #{handle}"
                `psql #{url} < #{sql_path}`
              end
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :port, type: :numeric
            define_method 'db:tunnel' do |handle|
              database = database_from_handle(handle)
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
            define_method 'db:deprovision' do |handle|
              database = database_from_handle(handle)
              say "Deprovisioning #{handle}..."
              database.update!(status: 'deprovisioned')
              database.create_operation!(type: 'deprovision')
            end

            private

            def appropriate_accounts(options)
              if options[:account]
                if (account = account_from_handle(options[:account]))
                  [account]
                else
                  fail Thor::Error, 'Specified account does not exist'
                end
              else
                Aptible::Api::Account.all(token: fetch_token)
              end
            end

            def present_account_databases(account)
              say "=== #{account.handle}"
              account.databases.each { |db| say db.handle }
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

            def database_from_handle(handle, options = { postgres_only: false })
              all = Aptible::Api::Database.all(token: fetch_token)
              database = all.find { |a|  a.handle == handle }

              unless database
                fail Thor::Error, "Could not find database #{handle}"
              end

              if options[:postgres_only] && database.type != 'postgresql'
                fail Thor::Error, 'This command only works for PostgreSQL'
              end

              database
            end

            def clone_database(source_handle, dest_handle)
              source = database_from_handle(source_handle)
              op = source.create_operation(type: 'clone', handle: dest_handle)
              poll_for_success(op)

              database_from_handle(dest_handle)
            end

            def dump_database(handle)
              execute_local_tunnel(handle) do |url|
                filename = "#{handle}.dump"
                say "Dumping to #{filename}"
                `pg_dump #{url} > #{filename}`
              end
            end

            # Creates a local tunnel and yields the url to it

            def execute_local_tunnel(handle)
              database = database_from_handle(handle, postgres_only: true)

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
