require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Ps
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App
            include Helpers::Env

            desc 'ps', 'Display running processes for an app'
            option :app
            option :remote, aliases: '-r'
            def ps
              app = ensure_app(options)

              host = app.account.bastion_host
              port = app.account.dumptruck_port

              set_env('ACCESS_TOKEN', fetch_token)
              set_env('APTIBLE_APP', app.handle)
              set_env('APTIBLE_CLI_COMMAND', 'ps')

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
