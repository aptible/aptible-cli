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

              # SSH's default behavior is as follows:
              #
              # - If a TTY is forced, one is allocated.
              # - If there is no command, then a TTY is allocated.
              # - If no-TTY is forced, then none is allocated.
              # - No TTY is allocated if stdin isn't a TTY.
              #
              # Unfortunately, in our case, this breaks, because we use a
              # forced-command, so we don't *ever* send a command, which causes
              # SSH to *always* allocate TTY, which causes a variety of
              # problems, not least of which is that stdout and stderr end up
              # merged.
              #
              # Now, it's pretty common for Aptible users to run commands in
              # their container with the intention of using a TTY (by e.g.
              # running `aptible ssh bash`), so we use a slightly different
              # heuristic from SSH: we allocate TTY iif there's no input or
              # output redirection going on.
              #
              # End users can always override this behavior with the
              # --force-tty option.
              tty_mode, interactive = if options[:force_tty]
                                        ['-tt', true]
                                      elsif [STDIN, STDOUT].all?(&:tty?)
                                        ['-t', true]
                                      else
                                        ['-T', false]
                                      end

              op = app.create_operation!(
                type: 'execute',
                command: command_from_args(*args),
                interactive: interactive
              )

              ENV['ACCESS_TOKEN'] = fetch_token
              opts = ['-o', 'SendEnv=ACCESS_TOKEN', tty_mode]
              exit_with_ssh_portal(op, *opts)
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
