require 'aws-sdk-s3'
require 'pathname'

module Aptible
  module CLI
    module Helpers
      module S3LogHelpers
        def ensure_aws_creds
          cred_errors = []
          unless ENV['AWS_ACCESS_KEY_ID']
            cred_errors << 'Missing environment variable: AWS_ACCESS_KEY_ID'
          end
          unless ENV['AWS_SECRET_ACCESS_KEY']
            cred_errors << 'Missing environment variable: AWS_SECRET_ACCESS_KEY'
          end
          raise Thor::Error, cred_errors.join(' ') if cred_errors.any?
        end

        def validate_log_search_options(options = {})
          id_options = [
            options[:app_id],
            options[:database_id],
            options[:endpoint_id],
            options[:container_id]
          ]
          date_options = [options[:start_date], options[:end_date]]
          unless options[:string_matches] || id_options.any?
            m = 'You must specify an option to identify the logs to download,' \
                ' either: --string-matches, --app-id, --database-id,' \
                ' --endpoint-id, or --container-id'
            raise Thor::Error, m
          end

          m = 'You cannot pass --app-id, --database-id, --endpoint-id, or ' \
              '--container-id when using --string-matches.'
          raise Thor::Error, m if options[:string_matches] && id_options.any?

          m = 'You must specify only one of ' \
              '--app-id, --database-id, --endpoint-id or --container-id'
          raise Thor::Error, m if id_options.any? && !id_options.one?

          m = 'The options --start-date/--end-date cannot be used when ' \
              'searching by string'
          raise Thor::Error, m if options[:string_matches] && date_options.any?

          m = 'You must pass both --start-date and --end-date'
          raise Thor::Error, m if date_options.any? && !date_options.all?

          if options[:container_id] && options[:container_id].length != 64
            raise Thor::Error, 'You must specify the full 64 char container ID'
          end
        end

        def info_from_path(file)
          properties = {}

          properties[:stack], _, properties[:schema],
            properties[:shasum], type_id, *remainder = file.split('/')

          properties[:id] = type_id.split('-').last.to_i
          properties[:type] = type_id.split('-').first

          case properties[:schema]
          when 'v2'
            # Eliminate the extensions
            split_by_dot = remainder.pop.split('.') - %w(log bck gz)
            properties[:container_id] = split_by_dot.first.delete!('-json')
            properties[:uploaded_at] = Time.parse("#{split_by_dot.last}Z")
          when 'v3'
            case properties[:type]
            when 'apps'
              properties[:service_id] = remainder.first.split('-').last.to_i
              file_name = remainder.second
            else
              file_name = remainder.pop
            end
            # The file name may have differing number of elements due to
            # docker file log rotation. So we eliminate some useless items
            # and then work from the beginning or end of the remaining to find
            # known elements, ignoring any .1 .2 (or none at all) extension
            # found in the middle of the file name. EG:
            # ['container_id', 'start_time', 'end_time']
            # or
            # ['container_id', '.1', 'start_time', 'end_time']]
            split_by_dot = file_name.split('.') - %w(log gz archived)
            properties[:container_id] = split_by_dot.first.delete!('-json')
            properties[:start_time] = Time.parse("#{split_by_dot[-2]}Z")
            properties[:end_time] = Time.parse("#{split_by_dot[-1]}Z")
          else
            m = "Cannot determine aptible log naming schema from #{file}"
            raise Thor::Error, m
          end
          properties
        end

        def decrypt_and_translate_s3_file(file, enc_key, region, bucket, path)
          # AWS warns us about using the legacy encryption schema
          s3 = Kernel.silence_warnings do
            Aws::S3::EncryptionV2::Client.new(
              encryption_key: enc_key, region: region,
              key_wrap_schema: :aes_gcm,
              content_encryption_schema: :aes_gcm_no_padding,
              security_profile: :v2_and_legacy
            )
          end

          # Just write it to a file directly
          location = File.join(path + file.split('/').drop(4).join('/'))
          FileUtils.mkdir_p(File.dirname(location))
          File.open(location, 'wb') do |f|
            # Is this memory efficient?
            s3.get_object(bucket: bucket, key: file, response_target: f)
          end
        end

        def find_s3_files_by_string_match(region, bucket, stack, strings)
          # This function just regex matches a provided string anywhwere
          # in the s3 path
          begin
            stack_logs = s3_client(region).bucket(bucket)
                                          .objects(prefix: stack)
                                          .map(&:key)
          rescue => error
            raise Thor::Error, error.message
          end
          strings.each do |s|
            stack_logs = stack_logs.select { |f| f =~ /#{s}/ }
          end
          stack_logs
        end

        def find_s3_files_by_attrs(region, bucket, stack,
                                   attrs, time_range = nil)
          # This function uses the known path schema to return files matching
          # any provided criteria. EG:
          # * attrs: { :type => 'app', :id => 123 }
          # * attrs: { :container_id => 'deadbeef' }

          begin
            stack_logs = s3_client(region).bucket(bucket)
                                          .objects(prefix: stack)
                                          .map(&:key)
          rescue => error
            raise Thor::Error, error.message
          end
          attrs.each do |k, v|
            stack_logs = stack_logs.select do |f|
              info_from_path(f)[k] == v
            end
          end

          if time_range
            # select only logs within the time range
            # TODO handle 'unknown' time ranges
            stack_logs = stack_logs.select do |f|
              info = info_from_path(f)
              first_log = info[:start_time]
              last_log = info[:end_time]
              if first_log.nil? || last_log.nil?
                m = 'Cannot determine precise timestamps of file: ' \
                    "#{f.split('/').drop(4).join('/')}"
                CLI.logger.warn m
                false
              else
                time_match?(time_range, first_log, last_log)
              end
            end
          end

          stack_logs
        end

        def time_match?(time_range, start_timestamp, end_timestamp)
          return false if time_range.last < start_timestamp
          return false if time_range.first > end_timestamp
          true
        end

        def utc_date(date_string)
          t_fmt = '%Y-%m-%d %Z'
          Time.strptime("#{date_string} UTC", t_fmt)
        rescue ArgumentError
          raise Thor::Error, 'Please provide dates in YYYY-MM-DD format'
        end

        def encryption_key(filesum, possible_keys)
          # The key can be determined from the sum
          possible_keys.each do |k|
            keysum = Digest::SHA256.hexdigest(Base64.strict_decode64(k))
            next unless keysum == filesum
            return Base64.strict_decode64(k)
          end
          m = "Did not find a matching key for shasum #{filesum}"
          raise Thor::Error, m
        end

        def s3_client(region)
          @s3_client ||= Aws::S3::Resource.new(region: region)
        end
      end
    end
  end
end
