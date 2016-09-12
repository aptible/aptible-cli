require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Ps
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'ps', 'Display running processes for an app - DEPRECATED'
            app_options
            def ps
              app = ensure_app(options)
              deprecated('This command is deprecated on Aptible v2 stacks.')

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_APP'] = app.href
              ENV['APTIBLE_CLI_COMMAND'] = 'ps'

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
