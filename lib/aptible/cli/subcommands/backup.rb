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
                 '[--container-size SIZE_MB] [--size SIZE_GB]',
                 'Restore a backup'
            option :handle, desc: 'a name to use for the new database'
            option :environment, desc: 'a different environment to restore to'
            option :container_size, type: :numeric
            option :size, type: :numeric
            define_method 'backup:restore' do |backup_id|
              backup = Aptible::Api::Backup.find(backup_id, token: fetch_token)
              raise Thor::Error, "Backup ##{backup_id} not found" if backup.nil?

              handle = options[:handle]
              unless handle
                ts_suffix = backup.created_at.getgm.strftime '%Y-%m-%d-%H-%M-%S'
                handle = "#{backup.database.handle}-at-#{ts_suffix}"
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
                disk_size: options[:size],
                destination_account: destination_account
              }.delete_if { |_, v| v.nil? }

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
                root.keyed_list('description') do |l|
                  database.each_backup do |backup|
                    break if backup.created_at < min_created_at
                    description = "#{backup.id}: #{backup.created_at}, " \
                      "#{backup.aws_region}"

                    l.object do |o|
                      o.value('id', backup.id)
                      o.value('description', description)
                      o.value('created_at', backup.created_at)
                      o.value('region', backup.aws_region)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
