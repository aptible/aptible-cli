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

        def databases_href
          href = '/databases'
          if Renderer.format != 'json'
            href = '/databases?per_page=5000&no_embed=true'
          end
          href
        end

        def databases_all
          Aptible::Api::Database.all(
            token: fetch_token,
            href: databases_href
          )
        end

        RdsDatabase = Struct.new(:handle, :created_at, :id, :raw)

        def external_rds_databases_all
          # HACK: 
          # must be super fault tolerant and cannot disrupt conventional db activity. probably need
          # to put around a rescue
          Aptible::Api::ExternalAwsResource.all(
              token: fetch_token
          )
            .select { |db| db.resource_type == "aws_rds_db_instance" }
            .map { |db| RdsDatabase.new(
              "aws:rds::#{db.resource_name}",
              db.id,
              db.created_at,
              db
            ) }
        end

        def derive_account_from_conns(db, preferred_acct = nil)
          # HACK: 
          # must be super fault tolerant and cannot disrupt conventional db activity. probably need
          # to put around a rescue
          conns = db.raw.app_external_aws_rds_connections
          return conns.find { |conn| conn.app.account.id == preferred_acct.id }.app.account if preferred_acct.present?

          conns.first.app.account
        end

        def external_rds_database_from_handle(handle)
          # HACK: 
          # must be super fault tolerant and cannot disrupt conventional db activity. probably need
          # to put around a rescue
          external_rds_databases_all.find { |a| a.handle == handle }
        end

        def databases_from_handle(handle, environment)
          databases = if environment
                        environment.databases
                      else
                        databases_all
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
            handle: dest_handle,
            container_size: options[:container_size],
            disk_size: options[:size],
            key_arn: options[:key_arn],
            instance_profile: options[:instance_profile],
            provisioned_iops: options[:provisioned_iops]
          }.reject { |_, v| v.nil? }

          if options[:logical]
            replication_params[:type] = 'replicate_logical'
            replication_params[:docker_ref] =
              options[:database_image].docker_repo
          else
            replication_params[:type] = 'replicate'
          end

          op = source.create_operation!(replication_params)
          attach_to_operation_logs(op)

          replica = databases_from_handle(dest_handle, source.account).first
          attach_to_operation_logs(replica.operations.last)
          replica
        end

        # Creates a local tunnel and yields the helper

        def with_local_tunnel(credential, port = 0, target_account = nil)
          op = if target_account.nil? 
            credential.create_operation!(type: 'tunnel', status: 'succeeded')
          else
            credential.create_operation!(type: 'tunnel', status: 'succeeded', destination_account: target_account.id)
          end

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

        def local_url(credential, local_port, forced_account = nil)
          remote_url = credential.connection_url

          uri = URI.parse(remote_url)
          domain = if forced_account.nil? 
            credential.database.account.stack.internal_domain
          else
            forced_account.stack.internal_domain
          end
          "#{uri.scheme}://#{uri.user}:#{uri.password}@" \
          "localhost.#{domain}:#{local_port}#{uri.path}"
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

        def validate_image_type(type)
          available_types = []

          Aptible::Api::DatabaseImage.all(token: fetch_token).each do |i|
            return true if i.type == type
            available_types << i.type
          end

          err = "No Database Image of type \"#{type}\""
          err = "#{err}, valid types: #{available_types.uniq.join(', ')}"
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
