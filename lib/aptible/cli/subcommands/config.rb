require 'shellwords'
module Aptible
  module CLI
    module Subcommands
      module Config
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App
            include Helpers::Telemetry

            desc 'config', "Print an app's current configuration"
            app_options
            def config
              telemetry(__method__, options)

              app = ensure_app(options)
              config = app.current_configuration
              env = config ? config.env : {}

              Formatter.render(Renderer.current) do |root|
                root.keyed_list('shell_export') do |list|
                  env.each_pair do |k, v|
                    list.object do |node|
                      node.value('key', k)
                      node.value('value', v)
                      node.value('shell_export', "#{k}=#{Shellwords.escape(v)}")
                    end
                  end
                end
              end
            end

            desc 'config:get [VAR1]',
                 "Print a specific key within an app's current configuration"
            app_options
            define_method 'config:get' do |*args|
              telemetry(__method__, options)

              app = ensure_app(options)
              config = app.current_configuration
              env = config ? config.env : {}

              Formatter.render(Renderer.current) do |root|
                key = args[0]
                value = env
                        .select { |k| k == key }
                        .map { |_, v| v }
                root.value(value)
              end
            end

            desc 'config:add [VAR1=VAL1] [VAR2=VAL2] [...]',
                 'Add an ENV variable to an app'
            app_options
            define_method 'config:add' do |*args|
              telemetry(__method__, options)

              # FIXME: define_method - ?! Seriously, WTF Thor.
              app = ensure_app(options)
              env = extract_env(args)
              operation = app.create_operation!(type: 'configure', env: env)
              CLI.logger.info 'Updating configuration and restarting app...'
              attach_to_operation_logs(operation)
            end

            desc 'config:set [VAR1=VAL1] [VAR2=VAL2] [...]',
                 'Add an ENV variable to an app'
            app_options
            define_method 'config:set' do |*args|
              telemetry(__method__, options)
              send('config:add', *args)
            end

            desc 'config:rm [VAR1] [VAR2] [...]',
                 'Remove an ENV variable from an app'
            app_options
            define_method 'config:rm' do |*args|
              telemetry(__method__, options)

              # FIXME: define_method - ?! Seriously, WTF Thor.
              app = ensure_app(options)
              env = Hash[args.map do |arg|
                arg = arg.split('=')[0]
                validate_env_key!(arg)
                [arg, '']
              end]
              operation = app.create_operation!(type: 'configure', env: env)
              CLI.logger.info 'Updating configuration and restarting app...'
              attach_to_operation_logs(operation)
            end

            desc 'config:unset [VAR1] [VAR2] [...]',
                 'Remove an ENV variable from an app'
            app_options
            define_method 'config:unset' do |*args|
              telemetry(__method__, options)
              send('config:rm', *args)
            end
          end
        end
      end
    end
  end
end
