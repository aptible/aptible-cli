module Aptible
  module CLI
    module Helpers
      module DateHelpers
        def utc_date(date_string)
          t_fmt = '%Y-%m-%d %Z'
          Time.strptime("#{date_string} UTC", t_fmt)
        rescue ArgumentError
          raise Thor::Error, 'Please provide dates in YYYY-MM-DD format'
        end

        def utc_datetime(datetime_string)
          Time.parse("#{datetime_string}Z")
        rescue ArgumentError
          nil
        end

        def utc_string(datetime_string)
          Time.parse("#{datetime_string}Z").utc
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
