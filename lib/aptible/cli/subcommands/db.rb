module Aptible
  module CLI
    module Subcommands
      module DB
        # rubocop:disable MethodLength
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::Token

            desc 'db:dump HANDLE', 'Dump a remote database to file'
            define_method 'db:dump' do |handle|
              begin
                database = database_from_handle(handle)
                unless database
                  fail Thor::Error, "Could not find database #{handle}"
                end
                unless database.type == 'postgresql'
                  fail Thor::Error, 'db:dump only works for PostgreSQL'
                end

                local_port = random_port
                pid = fork { establish_connection(database, local_port) }

                # TODO: Better test for connection readiness
                sleep 10

                filename = "#{handle}.dump"
                puts "Dumping to #{filename}"
                url = "aptible:#{database.passphrase}@localhost:#{local_port}"
                `pg_dump postgresql://#{url}/db > #{filename}`
              ensure
                Process.kill('HUP', pid) if pid
              end
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :port, type: :numeric
            define_method 'db:tunnel' do |handle|
              database = database_from_handle(handle)
              unless database
                fail Thor::Error, "Could not find database #{handle}"
              end

              local_port = options[:port] || random_port
              puts "Creating tunnel at localhost:#{local_port}..."
              establish_connection(database, local_port)
            end

            private

            def establish_connection(database, local_port)
              host = database.account.bastion_host
              port = database.account.bastion_port

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_DATABASE'] = database.handle
              tunnel_args = "-L #{local_port}:localhost:#{remote_port}"
              connection_args = "-o 'SendEnv=*' -p #{port} root@#{host}"
              opts = " -o 'SendEnv=*' -o StrictHostKeyChecking=no " \
                     '-o UserKnownHostsFile=/dev/null'
              command = "ssh #{opts} #{tunnel_args} #{connection_args}"
              Kernel.exec(command)
            end

            def database_from_handle(handle)
              Aptible::Api::Database.all(token: fetch_token).find do |a|
                a.handle == handle
              end
            end

            def random_port
              # Allocate a dummy server to discover an available port
              dummy = TCPServer.new('127.0.0.1', 0)
              port = dummy.addr[1]
              dummy.close
              port
            end

            def remote_port
              8080
            end
          end
        end
        # rubocop:enable MethodLength
      end
    end
  end
end
