require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Config
        # rubocop:disable MethodLength
        # rubocop:disable CyclomaticComplexity
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'config', "Print an app's current configuration"
            option :app
            def config
              app = ensure_app(options)
              config = app.current_configuration
              env = config ? config.env : nil
              puts formatted_config(env || {})
            end

            desc 'config:add', 'Add an ENV variable to an app'
            option :app
            define_method 'config:add' do |*args|
              # FIXME: define_method - ?! Seriously, WTF Thor.
              app = ensure_app(options)
              env = Hash[args.map { |arg| arg.split('=', 2) }]
              operation = app.create_operation(type: 'configure', env: env)
              puts 'Updating configuration and restarting app...'
              poll_for_success(operation)
            end

            desc 'config:set', 'Alias for config:add'
            option :app
            define_method 'config:set' do |*args|
              send('config:add', *args)
            end

            desc 'config:rm', 'Remove an ENV variable from an app'
            option :app
            define_method 'config:rm' do |*args|
              # FIXME: define_method - ?! Seriously, WTF Thor.
              app = ensure_app(options)
              env = Hash[args.map { |arg| [arg, ''] }]
              operation = app.create_operation(type: 'configure', env: env)
              puts 'Updating configuration and restarting app...'
              poll_for_success(operation)
            end

            desc 'config:unset', 'Alias for config:rm'
            option :app
            define_method 'config:unset' do |*args|
              send('config:add', *args)
            end

            private

            def formatted_config(env)
              env.map { |k, v| "#{k}=#{Shellwords.escape(v)}" }.join("\n")
            end
          end
        end
        # rubocop:enable CyclomaticComplexity
        # rubocop:enable MethodLength
      end
    end
  end
end
