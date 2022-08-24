require 'aws-sdk-s3'
require 'pathname'

module Aptible
  module CLI
    module Helpers
      module AwsHelpers
        def ensure_aws_creds
          cred_errors = []
          unless ENV['AWS_ACCESS_KEY_ID']
            cred_errors << 'Missing environment variable: AWS_ACCESS_KEY_ID.'
          end
          unless ENV['AWS_SECRET_ACCESS_KEY']
            cred_errors << 'Missing environment variable: AWS_SECRET_ACCESS_KEY.'
          end
          raise Thor::Error, cred_errors.join(' ') if cred_errors.any?
        end

        def info_from_path(file)
          properties = {}
          # All schemas must conform up to the version
          # $STACK/shareable/$VERSION/....
          properties[:schema] = file.split('/')[2]
          # So far, the SHASUM is always the top folder under the schema
          properties[:shasum] = file.split('/')[3]

          type_id = file.split('/')[4]
          properties[:id] = type_id.split('-').last.to_i
          properties[:type] = type_id.split('-').first

          case properties[:schema]
          when 'v2'
            file_name = file.split('/')[5]
            # Eliminate the extensions
            split_by_dot = file_name.split('.') - %w(log bck gz)
            properties[:container_id] = split_by_dot.first.delete!('-json')
            properties[:uploaded_at] = split_by_dot.last
          when 'v3'
            case properties[:type]
            when 'app'
              properties[:service_id] = file.split('/')[5].split('-').last.to_i
              file_name = file.split('/')[6]
            else
              file_name = file.split('/')[5]
            end
            split_by_dot = file_name.split('.') - %w(log bck gz)
            properties[:container_id] = split_by_dot.first.delete!('-json')
            # properties[:start_time]
            # properties[:end_time]
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
          location = File.join(path + file)
          FileUtils.mkdir_p(File.dirname(location))
          File.open(location, 'wb') do |f|
            reap = s3.get_object(bucket: bucket, key: file, response_target: f)
          end
        end

        def find_s3_files_by_string_match(region, bucket, stack, strings)
          begin
            stack_logs = s3_client(region).bucket(bucket).objects(prefix: stack).map(&:key)
          rescue => error
            raise Thor::Error, error.message
          end
          strings.each do |s|
            stack_logs = stack_logs.select { |f| f =~ /#{s}/ }
          end
          stack_logs
        end

        def find_s3_files_by_type_id
          false
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
