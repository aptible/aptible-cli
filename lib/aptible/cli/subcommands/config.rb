require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Config
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'config', "Print an app's current configuration"
            app_options
            def config
              app = ensure_app(options)
              config = app.current_configuration
              env = config ? config.env : nil
              puts formatted_config(env || {})
            end

            desc 'config:add', 'Add an ENV variable to an app'
            app_options
            define_method 'config:add' do |*args|
              # FIXME: define_method - ?! Seriously, WTF Thor.
              app = ensure_app(options)
              env = Hash[args.map { |arg| arg.split('=', 2) }]
              operation = app.create_operation(type: 'configure', env: env)
              puts 'Updating configuration and restarting app...'
              attach_to_operation_logs(operation)
            end

            desc 'config:set', 'Alias for config:add'
            app_options
            define_method 'config:set' do |*args|
              send('config:add', *args)
            end

            desc 'config:rm', 'Remove an ENV variable from an app'
            app_options
            define_method 'config:rm' do |*args|
              # FIXME: define_method - ?! Seriously, WTF Thor.
              app = ensure_app(options)
              env = Hash[args.map { |arg| [arg, ''] }]
              operation = app.create_operation(type: 'configure', env: env)
              puts 'Updating configuration and restarting app...'
              attach_to_operation_logs(operation)
            end

            desc 'config:unset', 'Alias for config:rm'
            app_options
            define_method 'config:unset' do |*args|
              send('config:rm', *args)
            end

            private

            def formatted_config(env)
              env = Hash[env.sort]
              env.map { |k, v| "#{k}=#{Shellwords.escape(v)}" }.join("\n")
            end
          end
        end
      end
    end
  end
end
