module Aptible
  module CLI
    module Helpers
      module DateHelpers
        # This should only be used by the method processing user date input in
        # S3LogHelpers. It is used to process a user-provided string into UTC.
        def utc_date(date_string)
          t_fmt = '%Y-%m-%d %Z'
          Time.strptime("#{date_string} UTC", t_fmt)
        rescue ArgumentError
          raise Thor::Error, 'Please provide dates in YYYY-MM-DD format'
        end

        # This should only be used by the method processing timestamps from S3
        # file names in S3LogHelpers. The file name does not include any time
        # zone information, but we know it to be in UTC, so we add the "Z"
        def utc_datetime(datetime_string)
          Time.parse("#{datetime_string}Z")
        rescue ArgumentError
          nil
        end

        # This is used to format timestamps returned by our API into a more
        # readable format.
        # EG, "2023-09-05T22:00:00.000Z" returns "2023-09-05 22:00:00 UTC"
        def utc_string(datetime_string)
          Time.parse(datetime_string)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
