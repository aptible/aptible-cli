require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Database
        include Helpers::Token
        include Helpers::Environment

        def ensure_database(options = {})
          db_handle = options[:db]
          environment_handle = options[:environment]

          fail Thor::Error, 'Database handle not specified' unless db_handle

          environment = environment_from_handle(environment_handle)
          if environment_handle && !environment
            fail Thor::Error, "Could not find environment #{environment_handle}"
          end
          databases = databases_from_handle(db_handle, environment)
          case databases.count
          when 1
            return databases.first
          when 0
            fail Thor::Error, "Could not find database #{db_handle}"
          else
            fail Thor::Error,
                 'Multiple databases exist, please specify environment'
          end
        end

        def databases_from_handle(handle, environment)
          if environment
            databases = environment.databases
          else
            databases = Aptible::Api::Database.all(token: fetch_token)
          end
          databases.select { |a| a.handle == handle }
        end

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

        def clone_database(source, dest_handle)
          op = source.create_operation(type: 'clone', handle: dest_handle)
          poll_for_success(op)

          databases_from_handle(dest_handle, source.account).first
        end

        def dump_database(database)
          execute_local_tunnel(database) do |url|
            filename = "#{database.handle}.dump"
            say "Dumping to #{filename}"
            `pg_dump #{url} > #{filename}`
          end
        end

        # Creates a local tunnel and yields the url to it
        def execute_local_tunnel(database)
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
