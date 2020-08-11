module Aptible
  module CLI
    module Subcommands
      module Backup
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Database

            desc 'backup:restore BACKUP_ID ' \
                 '[--environment ENVIRONMENT_HANDLE] [--handle HANDLE] ' \
                 '[--container-size SIZE_MB] [--disk-size SIZE_GB]',
                 'Restore a backup'
            option :handle, desc: 'a name to use for the new database'
            option :environment, desc: 'a different environment to restore to'
            option :container_size, type: :numeric
            option :size, type: :numeric
            option :disk_size, type: :numeric
            define_method 'backup:restore' do |backup_id|
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
                disk_size: options[:disk_size] || options[:size],
                destination_account: destination_account
              }.delete_if { |_, v| v.nil? }

              CLI.logger.warn([
                'You have used the "--size" option to specify a disk size.',
                'This option which be deprecated in a future version.',
                'Please use the "--disk-size" option, instead.'
              ].join("\n")) if options[:size]

              operation = backup.create_operation!(opts)
              CLI.logger.info "Restoring backup into #{handle}"
              attach_to_operation_logs(operation)

              account = destination_account || backup.account

              database = databases_from_handle(handle, account).first
              render_database(database, account)
            end

            desc 'backup:list DB_HANDLE', 'List backups for a database'
            option :environment
            option :max_age,
                   default: '1mo',
                   desc: 'Limit backups returned (example usage: 1w, 1y, etc.)'
            define_method 'backup:list' do |handle|
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
            option :environment
            option :max_age, default: '1y',
                             desc: 'Limit backups returned '\
                                   '(example usage: 1w, 1y, etc.)'
            define_method 'backup:orphaned' do
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
              backup = Aptible::Api::Backup.find(backup_id, token: fetch_token)
              raise Thor::Error, "Backup ##{backup_id} not found" if backup.nil?

              operation = backup.create_operation!(type: 'purge')
              CLI.logger.info "Purging backup #{backup_id}"
              attach_to_operation_logs(operation)
            end
          end
        end
      end
    end
  end
end
