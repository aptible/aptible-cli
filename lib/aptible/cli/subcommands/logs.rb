require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Logs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'logs', 'Follows logs from a running app'
            app_options
            def logs
              app = ensure_app(options)
              unless app.status == 'provisioned' && app.services.any?
                fail Thor::Error, 'Unable to retrieve logs. ' \
                                  "Have you deployed #{app.handle} yet?"
              end

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_APP'] = app.href
              ENV['APTIBLE_CLI_COMMAND'] = 'logs'

              cmd = dumptruck_ssh_command(app.account) + [
                '-o', 'SendEnv=ACCESS_TOKEN',
                '-o', 'SendEnv=APTIBLE_APP',
                '-o', 'SendEnv=APTIBLE_CLI_COMMAND'
              ]

              Kernel.exec(*cmd)
            end
          end
        end
      end
    end
  end
end
