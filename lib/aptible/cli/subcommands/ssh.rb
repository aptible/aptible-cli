require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module SSH
        # rubocop:disable MethodLength
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'ssh COMMAND', 'Run a command against an app'
            long_desc <<-LONGDESC
              Runs an interactive command against a remote Aptible app

              If specifying an app, invoke via: aptible ssh [--app=APP] COMMAND
            LONGDESC
            option :app
            def ssh(*args)
              app = ensure_app(options)
              host = app.account.bastion_host
              port = app.account.bastion_port

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_COMMAND'] = command_from_args(*args)
              ENV['APTIBLE_APP'] = options[:app]

              Kernel.exec "ssh -o 'SendEnv=*' -p #{port} root@#{host}"
            end

            private

            def command_from_args(*args)
              Shellwords.join(args)
            end
          end
        end
        # rubocop:enable MethodLength
      end
    end
  end
end
