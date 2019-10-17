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

            desc 'db:list', 'List all databases'
            option :environment
            define_method 'db:list' do
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
                 '[--container-size SIZE_MB] [--size SIZE_GB]',
                 'Create a new database'
            option :type, type: :string
            option :version, type: :string
            option :container_size, type: :numeric
            option :size, default: 10, type: :numeric
            option :environment
            define_method 'db:create' do |handle|
              account = ensure_environment(options)

              db_opts = {
                handle: handle,
                initial_container_size: options[:container_size],
                initial_disk_size: options[:size]
              }.delete_if { |_, v| v.nil? }

              type = options[:type]
              version = options[:version]

              if version && type
                image = find_database_image(type, version)
                db_opts[:type] = image.type
                db_opts[:database_image] = image
              elsif version
                raise Thor::Error, '--type is required when passing --version'
              else
                db_opts[:type] = type || 'postgresql'
              end

              database = account.create_database!(db_opts)

              op_opts = {
                type: 'provision',
                container_size: options[:container_size],
                disk_size: options[:size]
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
            option :environment
            define_method 'db:clone' do |source_handle, dest_handle|
              # TODO: Deprecate + recommend backup
              source = ensure_database(options.merge(db: source_handle))
              database = clone_database(source, dest_handle)
              render_database(database, database.account)
            end

            desc 'db:replicate HANDLE REPLICA_HANDLE ' \
                 '[--container-size SIZE_MB] [--size SIZE_GB]',
                 'Create a replica/follower of a database'
            option :environment
            option :container_size, type: :numeric
            option :size, type: :numeric
            define_method 'db:replicate' do |source_handle, dest_handle|
              source = ensure_database(options.merge(db: source_handle))
              CLI.logger.info "Replicating #{source_handle}..."
              database = replicate_database(source, dest_handle, options)
              render_database(database.reload, database.account)
            end

            desc 'db:dump HANDLE [pg_dump options]',
                 'Dump a remote database to file'
            option :environment
            define_method 'db:dump' do |handle, *dump_options|
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
            option :environment
            option :on_error_stop, type: :boolean
            define_method 'db:execute' do |handle, sql_path|
              database = ensure_database(options.merge(db: handle))
              with_postgres_tunnel(database) do |url|
                CLI.logger.info "Executing #{sql_path} against #{handle}"
                args = options[:on_error_stop] ? '-v ON_ERROR_STOP=true ' : ''
                `psql #{args}#{url} < #{sql_path}`
                exit $CHILD_STATUS.exitstatus unless $CHILD_STATUS.success?
              end
            end

            desc 'db:tunnel HANDLE', 'Create a local tunnel to a database'
            option :environment
            option :port, type: :numeric
            option :type, type: :string
            define_method 'db:tunnel' do |handle|
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
            option :environment
            define_method 'db:deprovision' do |handle|
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
            option :environment
            define_method 'db:backup' do |handle|
              database = ensure_database(options.merge(db: handle))
              CLI.logger.info "Backing up #{database.handle}..."
              op = database.create_operation!(type: 'backup')
              attach_to_operation_logs(op)
            end

            desc 'db:reload HANDLE', 'Reload a database'
            option :environment
            define_method 'db:reload' do |handle|
              database = ensure_database(options.merge(db: handle))
              CLI.logger.info "Reloading #{database.handle}..."
              op = database.create_operation!(type: 'reload')
              attach_to_operation_logs(op)
            end

            desc 'db:restart HANDLE ' \
                 '[--container-size SIZE_MB] [--size SIZE_GB]',
                 'Restart a database'
            option :environment
            option :container_size, type: :numeric
            option :size, type: :numeric
            define_method 'db:restart' do |handle|
              database = ensure_database(options.merge(db: handle))

              opts = {
                type: 'restart',
                container_size: options[:container_size],
                disk_size: options[:size]
              }.delete_if { |_, v| v.nil? }

              CLI.logger.info "Restarting #{database.handle}..."
              op = database.create_operation!(opts)
              attach_to_operation_logs(op)
            end

            desc 'db:url HANDLE', 'Display a database URL'
            option :environment
            option :type, type: :string
            define_method 'db:url' do |handle|
              database = ensure_database(options.merge(db: handle))
              credential = find_credential(database, options[:type])

              Formatter.render(Renderer.current) do |root|
                root.keyed_object('connection_url') do |node|
                  node.value('connection_url', credential.connection_url)
                end
              end
            end
          end
        end
      end
    end
  end
end
