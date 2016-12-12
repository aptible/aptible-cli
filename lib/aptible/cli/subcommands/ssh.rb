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
            app_options
            option :force_tty, type: :boolean
            def ssh(*args)
              app = ensure_app(options)

              op = app.create_operation!(type: 'execute',
                                         command: command_from_args(*args),
                                         status: 'succeeded')

              ENV['ACCESS_TOKEN'] = fetch_token
              opts = ['-o', 'SendEnv=ACCESS_TOKEN']
              opts << '-tt' if options[:force_tty]
              connect_to_ssh_portal(op, *opts)
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
