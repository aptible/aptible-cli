require 'aws-sdk-s3'
require 'shellwords'
require 'time'

module Aptible
  module CLI
    module Subcommands
      module Logs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::AppOrDatabase
            include Helpers::S3LogHelpers

            desc 'logs [--app APP | --database DATABASE]',
                 'Follows logs from a running app or database'
            app_or_database_options
            def logs
              resource = ensure_app_or_database(options)

              unless resource.status == 'provisioned'
                raise Thor::Error, 'Unable to retrieve logs. ' \
                                   "Have you deployed #{resource.handle} yet?"
              end

              op = resource.create_operation!(type: 'logs', status: 'succeeded')

              ENV['ACCESS_TOKEN'] = fetch_token
              exit_with_ssh_portal(op, '-o', 'SendEnv=ACCESS_TOKEN', '-T')
            end

            desc 'logs_from_archive --bucket NAME | --aws-region REGION | ' \
                 '--stack NAAME --decryption-keys ONE [TWO] [THREE] | ' \
                 '--download-location | --string-matches ONE [TWO] [THREE]',
                 'Retrieves logs from your S3 archive.'

            # Required to retrieve files
            option :region,
                   desc: 'The AWS region your S3 bucket resides in',
                   type: :string, required: true
            option :bucket,
                   desc: 'The name of your S3 bucket',
                   type: :string, required: true
            option :stack,
                   desc: 'The name of the Stack you wish to download logs from',
                   type: :string, required: true
            option :decryption_keys,
                   desc: 'The Aptible-provided keys for decription. ' \
                         '(Comma separated if multiple)',
                   type: :array, required: true

            # For identifying files to download
            option :string_matches,
                   desc: 'The strings you wish to match in log file names.',
                   type: :array
            option :app_id,
                   desc: 'The Application ID you wish to downloads logs for.',
                   type: :numeric
            option :database_id,
                   desc: 'The Database ID you wish to downloads logs for.',
                   type: :numeric
            option :proxy_id,
                   desc: 'The Endpoint ID you wish to downloads logs for.',
                   type: :numeric
            option :start_date,
                   desc: 'Get logs starting from this date (YYYY-MM-DD)',
                   type: :string
            option :end_date,
                   desc: 'Get logs before this date (YYYY-MM-DD)',
                   type: :string

            # We don't download by default
            option :download_location,
                   desc: 'The local path place downloaded log files. ' \
                         'If you do not set this option, the file names ' \
                         'will be shown, but not downloaded.',
                   type: :string

            def logs_from_archive
              t_fmt = '%Y-%m-%d %Z'

              ensure_aws_creds
              validate_log_search_options(options)

              id_options = [
                options[:app_id],
                options[:database_id],
                options[:proxy_id]
              ]

              date_options = [options[:start_date], options[:end_date]]

              r_type = 'apps' if options[:app_id]
              r_type = 'databases' if options[:database_id]
              r_type = 'proxy' if options[:proxy_id]

              if date_options.any?
                begin
                  start_d = Time.strptime("#{options[:start_date]} UTC", t_fmt)
                  end_d = Time.strptime("#{options[:end_date]} UTC", t_fmt)
                rescue ArgumentError
                  raise Thor::Error, 'Please provide dates in YYYY-MM-DD format'
                end
                time_range = [start_date, end_date]
                CLI.logger.info "Searching from #{start_d} to #{end_d}"
              else
                time_range = nil
              end

              # --string-matches is useful for matching by partial container id,
              # or for more flexibility than the currently suppored id_options
              # may allow for. We should update id_options with new use cases,
              # but leave string_matches as a way to download any named file
              if options[:string_matches]
                files = find_s3_files_by_string_match(
                  options[:region],
                  options[:bucket],
                  options[:stack],
                  options[:string_matches]
                )
              elsif id_options.any?
                files = find_s3_files_by_attrs(
                  options[:region],
                  options[:bucket],
                  options[:stack],
                  { type: r_type, id: id_options.compact.first },
                  time_range
                )
              end

              unless files.any?
                raise Thor::Error, 'No files found that matched all criterea'
              end

              CLI.logger.info "Found #{files.count} matching files..."

              if options[:download_location]
                # Since these files likely contain PHI, we will only download
                # them if the user is explicit about where to save them.
                files.each do |file|
                  shasum = info_from_path(file)[:shasum]
                  CLI.logger.info file
                  decrypt_and_translate_s3_file(
                    file,
                    encryption_key(shasum, options[:decryption_keys]),
                    options[:region],
                    options[:bucket],
                    options[:download_location]
                  )
                  CLI.logger.info 'Done!'
                end
              else
                files.each do |file|
                  CLI.logger.info file
                end
                m = 'No files were downloaded. Please provide a location ' \
                    'with --download-location to download the files.'
                raise Thor::Error, m
              end
            end
          end
        end
      end
    end
  end
end
