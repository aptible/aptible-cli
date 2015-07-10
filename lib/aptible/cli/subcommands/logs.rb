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
            option :app
            option :remote, aliases: '-r'
            def logs
              app = ensure_app(options)

              host = app.account.bastion_host
              port = app.account.dumptruck_port

              ENV['ACCESS_TOKEN'] = fetch_token
              ENV['APTIBLE_APP'] = app.handle

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
