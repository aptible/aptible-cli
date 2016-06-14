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
            define_method 'backup:list' do |handle|
              # TODO: Expose pagination from aptible-resource
              database = ensure_database(options.merge(db: handle))
              database.backups.each do |backup|
                say "#{backup.id}: #{backup.created_at}, #{backup.aws_region}"
              end
            end
          end
        end
      end
    end
  end
end
