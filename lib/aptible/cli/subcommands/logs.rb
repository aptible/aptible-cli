require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Logs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'logs', 'Follows logs from a running app or database'
            app_options
            option :database
            def logs
              resource = \
                if options[:database]
                  ensure_database(options.merge(db: options[:database]))
                else
                  app = ensure_app(options)

                  unless app.status == 'provisioned' && app.services.any?
                    fail Thor::Error, 'Unable to retrieve logs. ' \
                                      "Have you deployed #{app.handle} yet?"
                  end

                  app
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
