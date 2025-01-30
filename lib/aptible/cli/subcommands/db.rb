require 'term/ansicolor'
require 'uri'
require 'English'

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
            include Helpers::Telemetry

            desc 'db:list', 'List all databases'
            option :environment, aliases: '--env'
            define_method 'db:list' do
              telemetry(__method__, options)

              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'handle'
                ) do |node|
                  scoped_environments(options).each do |account|
                    account.each_database do |db|
                      node.object do |n|
                        ResourceFormatter.inject_database(n, db, account)
                      end
                    end
                  end
                end
              end
            end

            desc 'db:versions', 'List available database versions'
            define_method 'db:versions' do
              telemetry(__method__, options)

              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list('type', 'version') do |node|
                  Aptible::Api::DatabaseImage.all(
                    token: fetch_token
                  ).each do |database_image|
                    node.object do |n|
                      n.value('type', database_image.type)
                      n.value('version', database_image.version)
                      n.value('default', database_image.default)
                      n.value('description', database_image.description)
                      n.value('docker_repo', database_image.docker_repo)
                    end
                  end
                end
              end
            end

            desc 'db:create HANDLE ' \
                 '[--type TYPE] [--version VERSION] ' \
                 '[--container-size SIZE_MB] [--disk-size SIZE_GB] ' \
                 '[--container-profile PROFILE] [--iops IOPS] ' \
                 '[--key-arn KEY_ARN]',
                 'Create a new database'
            option :type, type: :string
            option :version, type: :string
            option :container_size, type: :numeric
            option :disk_size, default: 10, type: :numeric
            option :size, type: :numeric
            option :key_arn, type: :string
            option :environment, aliases: '--env'
            option :container_profile, type: :string,
                                       desc: 'Examples: m c r'
            option :iops, type: :numeric
            define_method 'db:create' do |handle|
              telemetry(__method__, options)

              account = ensure_environment(options)

              db_opts = {
                handle: handle,
                initial_container_size: options[:container_size],
                initial_disk_size: options[:disk_size],
                current_kms_arn: options[:key_arn]
              }.delete_if { |_, v| v.nil? }

              if options[:size]
                m = 'You have used the "--size" option to specify a disk size.'\
                    'This abiguous option has been removed.'\
                    'Please use the "--disk-size" option, instead.'
                raise Thor::Error, m
              end

              type = options[:type]
              version = options[:version]

              if version && type
                validate_image_type(type)
                image = find_database_image(type, version)
                db_opts[:type] = image.type
                db_opts[:database_image] = image
              elsif version
                raise Thor::Error, '--type is required when passing --version'
              else
                db_opts[:type] = type || 'postgresql'
                validate_image_type(db_opts[:type])
              end

              database = account.create_database!(db_opts)

              op_opts = {
                type: 'provision',
                container_size: options[:container_size],
                disk_size: options[:disk_size],
                instance_profile: options[:container_profile],
                provisioned_iops: options[:iops]
              }.delete_if { |_, v| v.nil? }

              op = database.create_operation(op_opts)

              if op.errors.any?
                # NOTE: If we fail to provision the database, we should try and
                # clean it up immediately. Note that this will not be possible
                # if we have an account that's not activated, but that's
                # arguably the desired UX here.
                database.create_operation!(type: 'deprovision')
                raise Thor::Error, op.errors.full_messages.first
              end

              attach_to_operation_logs(op)

              render_database(database.reload, account)
            end

            desc 'db:clone SOURCE DEST', 'Clone a database to create a new one'
            option :environment, aliases: '--env'
            define_method 'db:clone' do |source_handle, dest_handle|
              telemetry(__method__, options)

              # TODO: Deprecate + recommend backup
              source = ensure_database(options.merge(db: source_handle))
              database = clone_database(source, dest_handle)
              render_database(database, database.account)
            end

            desc 'db:replicate HANDLE REPLICA_HANDLE ' \
                 '[--container-size SIZE_MB] [--disk-size SIZE_GB] ' \
                 '[--container-profile PROFILE] [--iops IOPS] ' \
                 '[--logical --version VERSION] [--key-arn KEY_ARN]',
                 'Create a replica/follower of a database'
            option :environment, aliases: '--env'
            option :container_size, type: :numeric
            option :size, type: :numeric
            option :disk_size, type: :numeric
            option :logical, type: :boolean
            option :version, type: :string
            option :key_arn, type: :string
            option :container_profile, type: :string,
                                       desc: 'Examples: m c r'
            option :iops, type: :numeric
            define_method 'db:replicate' do |source_handle, dest_handle|
              telemetry(__method__, options)

              source = ensure_database(options.merge(db: source_handle))

              if options[:logical]
                if source.type != 'postgresql'
                  raise Thor::Error, 'Logical replication only works for ' \
                                     'PostgreSQL'
                end
                if options[:version]
                  image = find_database_image(source.type, options[:version])
                else
                  raise Thor::Error, '--version is required for logical ' \
                                     'replication'
                end
              end

              CLI.logger.info "Replicating #{source_handle}..."

              opts = {
                environment: options[:environment],
                container_size: options[:container_size],
                size: options[:disk_size],
                logical: options[:logical],
                database_image: image || nil,
                key_arn: options[:key_arn],
                instance_profile: options[:container_profile],
                provisioned_iops: options[:iops]
              }.delete_if { |_, v| v.nil? }

              if options[:size]
                m = 'You have used the "--size" option to specify a disk size.'\
                    'This abiguous option has been removed.'\
                    'Please use the "--disk-size" option, instead.'
                raise Thor::Error, m
              end

              database = replicate_database(source, dest_handle, opts)
              render_database(database.reload, database.account)
            end

            desc 'db:dump HANDLE [pg_dump options]',
                 'Dump a remote database to file'
            option :environment, aliases: '--env'
            define_method 'db:dump' do |handle, *dump_options|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))
              with_postgres_tunnel(database) do |url|
                filename = "#{handle}.dump"
                CLI.logger.info "Dumping to #{filename}"
                `pg_dump #{url} #{dump_options.shelljoin} > #{filename}`
                exit $CHILD_STATUS.exitstatus unless $CHILD_STATUS.success?
              end
            end

            desc 'db:execute HANDLE SQL_FILE [--on-error-stop]',
                 'Executes sql against a database'
            option :environment, aliases: '--env'
            option :on_error_stop, type: :boolean
            define_method 'db:execute' do |handle, sql_path|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))
              with_postgres_tunnel(database) do |url|
                CLI.logger.info "Executing #{sql_path} against #{handle}"
                args = options[:on_error_stop] ? '-v ON_ERROR_STOP=true ' : ''
                `psql #{args}#{url} < #{sql_path}`
                exit $CHILD_STATUS.exitstatus unless $CHILD_STATUS.success?
              end
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :environment, aliases: '--env'
            option :port, type: :numeric
            option :type, type: :string
            define_method 'db:tunnel' do |handle|
              telemetry(__method__, options)

              desired_port = Integer(options[:port] || 0)
              database = ensure_database(options.merge(db: handle))

              credential = find_credential(database, options[:type])

              m = "Creating #{credential.type} tunnel to #{database.handle}..."
              CLI.logger.info m

              if options[:type].nil?
                types = database.database_credentials.map(&:type)
                unless types.empty?
                  valid = types.join(', ')
                  CLI.logger.info 'Use --type TYPE to specify a tunnel type'
                  CLI.logger.info "Valid types for #{database.handle}: #{valid}"
                end
              end

              with_local_tunnel(credential, desired_port) do |tunnel_helper|
                port = tunnel_helper.port
                CLI.logger.info "Connect at #{local_url(credential, port)}"

                uri = URI(local_url(credential, port))
                db = uri.path.gsub(%r{^/}, '')
                CLI.logger.info 'Or, use the following arguments:'
                CLI.logger.info "* Host: #{uri.host}"
                CLI.logger.info "* Port: #{uri.port}"
                CLI.logger.info "* Username: #{uri.user}" unless uri.user.empty?
                CLI.logger.info "* Password: #{uri.password}"
                CLI.logger.info "* Database: #{db}" unless db.empty?

                CLI.logger.info 'Connected. Ctrl-C to close connection.'

                begin
                  tunnel_helper.wait
                rescue Interrupt
                  CLI.logger.warn 'Closing tunnel'
                end
              end
            end

            desc 'db:deprovision HANDLE', 'Deprovision a database'
            option :environment, aliases: '--env'
            define_method 'db:deprovision' do |handle|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))
              CLI.logger.info "Deprovisioning #{database.handle}..."
              op = database.create_operation!(type: 'deprovision')
              begin
                attach_to_operation_logs(op)
              rescue HyperResource::ClientError => e
                # A 404 here means that the operation completed successfully,
                # and was removed faster than attach_to_operation_logs
                # could attach to the logs.
                raise if e.response.status != 404
              end
            end

            desc 'db:backup HANDLE', 'Backup a database'
            option :environment, aliases: '--env'
            define_method 'db:backup' do |handle|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))
              CLI.logger.info "Backing up #{database.handle}..."
              op = database.create_operation!(type: 'backup')
              attach_to_operation_logs(op)
            end

            desc 'db:reload HANDLE', 'Reload a database'
            option :environment, aliases: '--env'
            define_method 'db:reload' do |handle|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))
              CLI.logger.info "Reloading #{database.handle}..."
              op = database.create_operation!(type: 'reload')
              attach_to_operation_logs(op)
            end

            desc 'db:restart HANDLE ' \
                 '[--container-size SIZE_MB] [--disk-size SIZE_GB] ' \
                 '[--container-profile PROFILE] [--iops IOPS] ' \
                 '[--volume-type [gp2, gp3]]',
                 'Restart a database'
            option :environment, aliases: '--env'
            option :container_size, type: :numeric
            option :container_profile, type: :string,
                                       desc: 'Examples: m c r'
            option :disk_size, type: :numeric
            option :size, type: :numeric
            option :iops, type: :numeric
            option :volume_type
            define_method 'db:restart' do |handle|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))

              opts = {
                type: 'restart',
                container_size: options[:container_size],
                disk_size: options[:disk_size],
                provisioned_iops: options[:iops],
                ebs_volume_type: options[:volume_type],
                instance_profile: options[:container_profile]
              }.delete_if { |_, v| v.nil? }

              if options[:size]
                m = 'You have used the "--size" option to specify a disk size.'\
                    'This abiguous option has been removed.'\
                    'Please use the "--disk-size" option, instead.'
                raise Thor::Error, m
              end

              CLI.logger.info "Restarting #{database.handle}..."
              op = database.create_operation!(opts)
              attach_to_operation_logs(op)
            end

            desc 'db:modify HANDLE ' \
                 '[--iops IOPS] [--volume-type [gp2, gp3]]',
                 'Modify a database disk'
            option :environment, aliases: '--env'
            option :iops, type: :numeric
            option :volume_type
            define_method 'db:modify' do |handle|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))

              opts = {
                type: 'modify',
                provisioned_iops: options[:iops],
                ebs_volume_type: options[:volume_type],
                instance_profile: options[:container_profile]
              }.delete_if { |_, v| v.nil? }

              CLI.logger.info "Modifying #{database.handle}..."
              op = database.create_operation!(opts)
              attach_to_operation_logs(op)
            end

            desc 'db:url HANDLE', 'Display a database URL'
            option :environment, aliases: '--env'
            option :type, type: :string
            define_method 'db:url' do |handle|
              telemetry(__method__, options)

              database = ensure_database(options.merge(db: handle))
              credential = find_credential(database, options[:type])

              Formatter.render(Renderer.current) do |root|
                root.keyed_object('connection_url') do |node|
                  node.value('connection_url', credential.connection_url)
                end
              end
            end

            desc 'db:rename OLD_HANDLE NEW_HANDLE [--environment'\
                 ' ENVIRONMENT_HANDLE]', 'Rename a database handle. In order'\
                 ' for the new database handle to appear in log drain and'\
                 ' metric drain destinations, you must reload the database.'
            option :environment, aliases: '--env'
            define_method 'db:rename' do |old_handle, new_handle|
              telemetry(__method__, options)

              env = ensure_environment(options)
              db = ensure_database(options.merge(db: old_handle))
              db.update!(handle: new_handle)
              m1 = "In order for the new database name (#{new_handle}) to"\
                   ' appear in log drain and metric drain destinations,'\
                   ' you must reload the database.'
              m2 = 'You can reload your database with this command: "aptible'\
                   " db:reload #{new_handle} --environment #{env.handle}\""
              CLI.logger.warn m1
              CLI.logger.info m2
            end
          end
        end
      end
    end
  end
end
