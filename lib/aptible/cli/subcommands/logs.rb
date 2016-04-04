require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Logs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'logs', 'Follows logs from a running app - DEPRECATED'
            app_options
            def logs
              app = ensure_app(options)

              puts 'DEPRECATION NOTICE: ' \
                   'This command is deprecated on Aptible v2 stacks. ' \
                   'Please contact support@aptible.com with any questions.'
              unless app.status == 'provisioned' && app.services.any?
                fail Thor::Error, 'Unable to retrieve logs. ' \
                                  "Have you deployed #{app.handle} yet?"
              end

              host = app.account.bastion_host
              port = app.account.dumptruck_port

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_APP'] = app.handle
              ENV['APTIBLE_CLI_COMMAND'] = 'logs'

              opts = " -o 'SendEnv=*' -o StrictHostKeyChecking=no " \
                     '-o UserKnownHostsFile=/dev/null'
              Kernel.exec "ssh #{opts} -p #{port} root@#{host}"
            end
          end
        end
      end
    end
  end
end
