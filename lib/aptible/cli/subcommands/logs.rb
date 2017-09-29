require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Logs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::AppOrDatabase

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
          end
        end
      end
    end
  end
end
