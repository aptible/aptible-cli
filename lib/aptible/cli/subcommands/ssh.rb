require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module SSH
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'ssh [COMMAND]', 'Run a command against an app'
            long_desc <<-LONGDESC
              Runs an interactive command against a remote Aptible app

              If specifying an app, invoke via: aptible ssh [--app=APP] COMMAND
            LONGDESC
            option :app
            option :environment
            option :remote, aliases: '-r'
            option :force_tty, type: :boolean
            def ssh(*args)
              app = ensure_app(options)
              host = app.account.bastion_host
              port = app.account.bastion_port

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_COMMAND'] = command_from_args(*args)
              ENV['APTIBLE_APP'] = app.handle

              opts = options[:force_tty] ? '-t -t' : ''
              opts << " -o 'SendEnv=*' -o StrictHostKeyChecking=no " \
                      '-o UserKnownHostsFile=/dev/null'
              Kernel.exec "ssh #{opts} -p #{port} root@#{host}"
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
