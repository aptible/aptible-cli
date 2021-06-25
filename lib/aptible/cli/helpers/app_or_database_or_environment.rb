module Aptible
  module CLI
    module Helpers
      module AppOrDatabaseOrEnvironment
        include Helpers::App
        include Helpers::Database
        include Helpers::Environment

        module ClassMethods
          def app_or_database_options
            app_options
            option :database
          end
        end

        def ensure_app_or_database_or_environment(options = {})
          if options[:app] && options[:database]
            m = 'You must specify either --app, --database, or --environment'
            raise Thor::Error, m
          end

          if options[:database]
            ensure_database(options.merge(db: options[:database]))
          elsif options[:app]
            ensure_app(options)
          elsif options[:environment]
            ensure_environment(options)
          end
        end

        def self.included(base)
          base.extend(ClassMethods)
        end
      end
    end
  end
end
