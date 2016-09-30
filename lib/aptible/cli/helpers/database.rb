require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Database
        include Helpers::Token
        include Helpers::Environment
        include Helpers::Ssh

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
            err = 'Multiple databases exist, please specify with --environment'
            fail Thor::Error, err
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

        def clone_database(source, dest_handle)
          op = source.create_operation!(type: 'clone', handle: dest_handle)
          poll_for_success(op)

          databases_from_handle(dest_handle, source.account).first
        end

        # Creates a local tunnel and yields the helper

        def with_local_tunnel(database, port = 0)
          tunnel_helper = Helpers::Tunnel.new(ssh_env(database),
                                              ssh_args(database))

          tunnel_helper.start(port)
          yield tunnel_helper if block_given?
          tunnel_helper.stop
        end

        # Creates a local PG tunnel and yields the url to it

        def with_postgres_tunnel(database)
          if database.type != 'postgresql'
            fail Thor::Error, 'This command only works for PostgreSQL'
          end

          with_local_tunnel(database) do |tunnel_helper|
            auth = "aptible:#{database.passphrase}"
            host = "localhost.aptible.in:#{tunnel_helper.port}"
            yield "postgresql://#{auth}@#{host}/db"
          end
        end

        def local_url(database, local_port)
          remote_url = database.connection_url
          uri = URI.parse(remote_url)

          "#{uri.scheme}://#{uri.user}:#{uri.password}@" \
          "localhost.aptible.in:#{local_port}#{uri.path}"
        end

        def ssh_env(database)
          {
            'ACCESS_TOKEN' => fetch_token,
            'APTIBLE_DATABASE' => database.href
          }
        end

        def ssh_args(database)
          broadwayjoe_ssh_command(database.account) + [
            '-o', 'SendEnv=ACCESS_TOKEN',
            '-o', 'SendEnv=APTIBLE_DATABASE'
          ]
        end
      end
    end
  end
end
