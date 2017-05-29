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
              deprecated('This command is deprecated on Aptible v2 stacks.')

              app = ensure_app(options)

              op = app.create_operation!(type: 'ps', status: 'succeeded')

              ENV['ACCESS_TOKEN'] = fetch_token
              opts = ['-o', 'SendEnv=ACCESS_TOKEN']
              exit_with_ssh_portal(op, *opts)
            end
          end
        end
      end
    end
  end
end
