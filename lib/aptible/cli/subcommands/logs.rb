require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Logs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App
            include Helpers::Database

            desc 'logs', 'Follows logs from a running app or database'
            app_options
            option :database
            def logs
              if options[:app] && options[:database]
                m = 'You must specify only one of --app and --database'
                fail Thor::Error, m
              end

              resource = \
                if options[:database]
                  ensure_database(options.merge(db: options[:database]))
                else
                  ensure_app(options)
                end

              unless resource.status == 'provisioned'
                fail Thor::Error, 'Unable to retrieve logs. ' \
                                  "Have you deployed #{resource.handle} yet?"
              end

              op = resource.create_operation!(type: 'logs', status: 'succeeded')

              ENV['ACCESS_TOKEN'] = fetch_token
              connect_to_ssh_portal(op, '-o', 'SendEnv=ACCESS_TOKEN', '-T')
            end
          end
        end
      end
    end
  end
end
