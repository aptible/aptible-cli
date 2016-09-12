require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module SSH
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App
            include Helpers::Ssh

            desc 'ssh [COMMAND]', 'Run a command against an app'
            long_desc <<-LONGDESC
              Runs an interactive command against a remote Aptible app

              If specifying an app, invoke via: aptible ssh [--app=APP] COMMAND
            LONGDESC
            app_options
            option :force_tty, type: :boolean
            def ssh(*args)
              app = ensure_app(options)

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_APP'] = app.href
              ENV['APTIBLE_COMMAND'] = command_from_args(*args)

              cmd = broadwayjoe_ssh_command(app.account) + [
                '-o', 'SendEnv=ACCESS_TOKEN',
                '-o', 'SendEnv=APTIBLE_APP',
                '-o', 'SendEnv=APTIBLE_COMMAND'
              ]
              cmd << '-tt' if options[:force_tty]

              Kernel.exec(*cmd)
            end

            private

            def command_from_args(*args)
              args.empty? ? '/bin/bash' : Shellwords.join(args)
            end
          end
        end
      end
    end
  end
end
