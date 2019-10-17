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

          raise Thor::Error, 'Database handle not specified' unless db_handle

          environment = environment_from_handle(environment_handle)
          if environment_handle && !environment
            raise Thor::Error,
                  "Could not find environment #{environment_handle}"
          end
          databases = databases_from_handle(db_handle, environment)
          case databases.count
          when 1
            return databases.first
          when 0
            raise Thor::Error, "Could not find database #{db_handle}"
          else
            err = 'Multiple databases exist, please specify with --environment'
            raise Thor::Error, err
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

        def clone_database(source, dest_handle)
          op = source.create_operation!(type: 'clone', handle: dest_handle)
          attach_to_operation_logs(op)

          databases_from_handle(dest_handle, source.account).first
        end

        def replicate_database(source, dest_handle, options)
          replication_params = {
            type: 'replicate',
            handle: dest_handle,
            container_size: options[:container_size],
            disk_size: options[:size]
          }.reject { |_, v| v.nil? }
          op = source.create_operation!(replication_params)
          attach_to_operation_logs(op)

          replica = databases_from_handle(dest_handle, source.account).first
          attach_to_operation_logs(replica.operations.last)
          replica
        end

        # Creates a local tunnel and yields the helper

        def with_local_tunnel(credential, port = 0)
          op = credential.create_operation!(type: 'tunnel', status: 'succeeded')

          with_ssh_cmd(op) do |base_ssh_cmd, ssh_credential|
            ssh_cmd = base_ssh_cmd + ['-o', 'SendEnv=ACCESS_TOKEN']
            ssh_env = { 'ACCESS_TOKEN' => fetch_token }

            socket_path = ssh_credential.ssh_port_forward_socket
            tunnel_helper = Helpers::Tunnel.new(ssh_env, ssh_cmd, socket_path)

            tunnel_helper.start(port)
            yield tunnel_helper if block_given?
            tunnel_helper.stop
          end
        end

        # Creates a local PG tunnel and yields the url to it

        def with_postgres_tunnel(database)
          if database.type != 'postgresql'
            raise Thor::Error, 'This command only works for PostgreSQL'
          end

          credential = find_credential(database)

          with_local_tunnel(credential) do |tunnel_helper|
            yield local_url(credential, tunnel_helper.port)
          end
        end

        def local_url(credential, local_port)
          remote_url = credential.connection_url
          uri = URI.parse(remote_url)

          "#{uri.scheme}://#{uri.user}:#{uri.password}@" \
          "localhost.aptible.in:#{local_port}#{uri.path}"
        end

        def find_credential(database, type = nil)
          unless database.provisioned?
            raise Thor::Error, "Database #{database.handle} is not provisioned"
          end

          finder = proc { |c| c.default }
          finder = proc { |c| c.type == type } if type
          credential = database.database_credentials.find(&finder)

          return credential if credential

          types = database.database_credentials.map(&:type)

          # On v1, we fallback to the DB. We make sure to make --type work, to
          # avoid a confusing experience for customers.
          if database.account.stack.version == 'v1'
            types << database.type
            types.uniq!
            return database if type.nil? || type == database.type
          end

          valid = types.join(', ')

          err = 'No default credential for database'
          err = "No credential with type #{type} for database" if type
          raise Thor::Error, "#{err}, valid credential types: #{valid}"
        end

        def find_database_image(type, version)
          available_versions = []

          Aptible::Api::DatabaseImage.all(token: fetch_token).each do |i|
            next unless i.type == type
            return i if i.version == version
            available_versions << i.version
          end

          err = "No Database Image of type #{type} with version #{version}"
          err = "#{err}, valid versions: #{available_versions.join(' ')}"
          raise Thor::Error, err
        end

        def render_database(database, account)
          Formatter.render(Renderer.current) do |root|
            root.keyed_object('connection_url') do |node|
              ResourceFormatter.inject_database(node, database, account)
            end
          end
        end
      end
    end
  end
end
