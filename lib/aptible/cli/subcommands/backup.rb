module Aptible
  module CLI
    module Subcommands
      module Backup
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Database
            include Helpers::Telemetry

            desc 'backup:restore BACKUP_ID ' \
                 '[--environment ENVIRONMENT_HANDLE] [--handle HANDLE] ' \
                 '[--container-size SIZE_MB] [--disk-size SIZE_GB] ' \
                 '[--container-profile PROFILE] [--iops IOPS] ' \
                 '[--key-arn KEY_ARN]',
                 'Restore a backup'
            option :handle, desc: 'a name to use for the new database'
            option :environment, aliases: '--env',
                                 desc: 'a different environment to restore to'
            option :container_size, type: :numeric
            option :size, type: :numeric
            option :disk_size, type: :numeric
            option :key_arn, type: :string
            option :container_profile, type: :string,
                                       desc: 'Examples: m c r'
            option :iops, type: :numeric
            define_method 'backup:restore' do |backup_id|
              telemetry(__method__, options.merge(backup_id: backup_id))

              backup = Aptible::Api::Backup.find(backup_id, token: fetch_token)
              raise Thor::Error, "Backup ##{backup_id} not found" if backup.nil?

              handle = options[:handle]
              unless handle
                ts_suffix = backup.created_at.getgm.strftime '%Y-%m-%d-%H-%M-%S'
                handle =
                  "#{backup.database_with_deleted.handle}-at-#{ts_suffix}"
              end

              destination_account = if options[:environment]
                                      ensure_environment(
                                        environment: options[:environment]
                                      )
                                    end

              opts = {
                type: 'restore',
                handle: handle,
                container_size: options[:container_size],
                disk_size: options[:disk_size],
                destination_account: destination_account,
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

              operation = backup.create_operation!(opts)
              CLI.logger.info "Restoring backup into #{handle}"
              attach_to_operation_logs(operation)

              account = destination_account || backup.account

              database = databases_from_handle(handle, account).first
              render_database(database, account)
            end

            desc 'backup:list DB_HANDLE', 'List backups for a database'
            option :environment, aliases: '--env'
            option :max_age,
                   default: '99y',
                   desc: 'Limit backups returned (example usage: 1w, 1y, etc.)'
            define_method 'backup:list' do |handle|
              telemetry(__method__, options.merge(handle: handle))

              age = ChronicDuration.parse(options[:max_age])
              raise Thor::Error, "Invalid age: #{options[:max_age]}" if age.nil?
              min_created_at = Time.now - age

              database = ensure_database(options.merge(db: handle))

              Formatter.render(Renderer.current) do |root|
                root.keyed_list('description') do |node|
                  database.each_backup do |backup|
                    if backup.created_at < min_created_at && !backup.copied_from
                      break
                    end
                    node.object do |n|
                      ResourceFormatter.inject_backup(n, backup)
                    end
                  end
                end
              end
            end

            desc 'backup:orphaned', 'List backups associated with ' \
                                    'deprovisioned databases'
            option :environment, aliases: '--env'
            option :max_age, default: '99y',
                             desc: 'Limit backups returned '\
                                   '(example usage: 1w, 1y, etc.)'
            define_method 'backup:orphaned' do
              telemetry(__method__, options)

              age = ChronicDuration.parse(options[:max_age])
              raise Thor::Error, "Invalid age: #{options[:max_age]}" if age.nil?
              min_created_at = Time.now - age

              Formatter.render(Renderer.current) do |root|
                root.keyed_list('description') do |node|
                  scoped_environments(options).each do |account|
                    account.each_orphaned_backup do |backup|
                      created_at = backup.created_at
                      copied_from = backup.copied_from
                      break if created_at < min_created_at && !copied_from
                      node.object do |n|
                        ResourceFormatter.inject_backup(
                          n, backup, include_db: true
                        )
                      end
                    end
                  end
                end
              end
            end

            desc 'backup:purge BACKUP_ID',
                 'Permanently delete a backup and any copies of it'
            define_method 'backup:purge' do |backup_id|
              telemetry(__method__, options.merge(backup_id: backup_id))

              backup = Aptible::Api::Backup.find(backup_id, token: fetch_token)
              raise Thor::Error, "Backup ##{backup_id} not found" if backup.nil?

              operation = backup.create_operation!(type: 'purge')
              CLI.logger.info "Purging backup #{backup_id}"
              begin
                attach_to_operation_logs(operation)
              rescue HyperResource::ClientError => e
                # A 404 here means that the operation completed successfully,
                # and was removed faster than attach_to_operation_logs
                # could attach to the logs.
                raise if e.response.status != 404
              end
            end
          end
        end
      end
    end
  end
end
