module Aptible
  module CLI
    module Subcommands
      module Backup
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Database

            desc 'backup:restore [--handle HANDLE] [--size SIZE_GB]',
                 'Restore a backup'
            option :handle
            option :size, type: :numeric
            define_method 'backup:restore' do |backup_id|
              backup = Aptible::Api::Backup.find(backup_id, token: fetch_token)
              fail Thor::Error, "Backup ##{backup_id} not found" if backup.nil?
              handle = options[:handle]
              unless handle
                ts_suffix = backup.created_at.getgm.strftime '%Y-%m-%d-%H-%M-%S'
                handle = "#{backup.database.handle}-at-#{ts_suffix}"
              end

              opts = {
                type: 'restore',
                handle: handle,
                disk_size: options[:size]
              }.delete_if { |_, v| v.nil? }

              operation = backup.create_operation!(opts)
              say "Restoring backup into #{handle}"
              attach_to_operation_logs(operation)
            end

            desc 'backup:list DB_HANDLE', 'List backups for a database'
            option :environment
            option :max_age,
                   default: '1mo',
                   desc: 'Limit backups returned (example usage: 1w, 1y, etc.)'
            define_method 'backup:list' do |handle|
              age = ChronicDuration.parse(options[:max_age])
              fail Thor::Error, "Invalid age: #{options[:max_age]}" if age.nil?
              min_created_at = Time.now - age

              database = ensure_database(options.merge(db: handle))
              database.each_backup do |backup|
                break if backup.created_at < min_created_at
                say "#{backup.id}: #{backup.created_at}, #{backup.aws_region}"
              end
            end
          end
        end
      end
    end
  end
end
