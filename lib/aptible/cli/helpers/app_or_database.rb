module Aptible
  module CLI
    module Helpers
      module AppOrDatabase
        include Helpers::App
        include Helpers::Database

        module ClassMethods
          def app_or_database_options
            app_options
            option :database
          end
        end

        def ensure_app_or_database(options = {})
          if options[:app] && options[:database]
            m = 'You must specify only one of --app and --database'
            raise Thor::Error, m
          end

          if options[:database]
            ensure_database(options.merge(db: options[:database]))
          else
            ensure_app(options)
          end
        end

        def self.included(base)
          base.extend(ClassMethods)
        end
      end
    end
  end
end
