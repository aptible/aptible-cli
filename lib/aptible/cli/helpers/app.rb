require 'aptible/api'

# Avoid requiring the git gem upfront, since it'll fail to load if git isn't
# available, whereas we're able to gracefully handle that by requiring the
# --app and / or --environment flags.
autoload :Git, 'git'

module Aptible
  module CLI
    module Helpers
      module App
        include Helpers::Token
        include Helpers::Environment

        module ClassMethods
          def app_options
            option :app
            option :environment
            option :remote, aliases: '-r'
          end
        end

        def self.included(base)
          base.extend ClassMethods
        end

        class HandleFromGitRemote
          PATTERN = %r{
            :((?<environment_handle>[0-9a-z\-_\.]+?)/)?
            (?<app_handle>[0-9a-z\-_\.]+)\.git
            \z
          }x

          def self.parse(url)
            PATTERN.match(url) || {}
          end
        end

        class OptionsHandleStrategy
          attr_reader :app_handle, :env_handle

          def initialize(options)
            @app_handle = options[:app]
            @env_handle = options[:environment]
          end

          def usable?
            !app_handle.nil?
          end

          def explain
            '(options provided via CLI arguments)'
          end
        end

        class GitRemoteHandleStrategy
          def initialize(options)
            @remote_name = options[:remote] || ENV['APTIBLE_REMOTE'] ||
                           'aptible'
            @repo_dir = Dir.pwd
          end

          def app_handle
            handles_from_remote[:app_handle]
          end

          def env_handle
            handles_from_remote[:environment_handle]
          end

          def usable?
            !app_handle.nil? && !env_handle.nil?
          end

          def explain
            "(options derived from git remote #{@remote_name})"
          end

          private

          def handles_from_remote
            @handles_from_remote ||= \
              begin
                git = Git.open(@repo_dir)
                remote_url = git.remote(@remote_name).url || ''
                HandleFromGitRemote.parse(remote_url)
              rescue StandardError
                # TODO: Consider being more specific here (ArgumentError?)
                {}
              end
          end
        end

        def ensure_app(options = {})
          s = handle_strategies.map { |cls| cls.new(options) }.find(&:usable?)

          if s.nil?
            err = 'Could not find app in current working directory, please ' \
                  'specify with --app'
            raise Thor::Error, err
          end

          environment = nil
          if s.env_handle
            environment = environment_from_handle(s.env_handle)
            if environment.nil?
              err_bits = ['Could not find environment', s.env_handle]
              err_bits << s.explain
              raise Thor::Error, err_bits.join(' ')
            end
          end

          apps = apps_from_handle(s.app_handle, environment)

          case apps.count
          when 1
            return apps.first
          when 0
            err_bits = ['Could not find app', s.app_handle]
            if environment
              err_bits << 'in environment'
              err_bits << environment.handle
            else
              err_bits << 'in any environment'
            end
            err_bits << s.explain
            raise Thor::Error, err_bits.join(' ')
          else
            err = "Multiple apps named #{s.app_handle} exist, please specify " \
                  'with --environment'
            raise Thor::Error, err
          end
        end

        def ensure_service(options, type)
          app = ensure_app(options)
          service = app.services.find { |s| s.process_type == type }

          if service.nil?
            valid_types = if app.services.empty?
                            'NONE (deploy the app first)'
                          else
                            app.services.map(&:process_type).join(', ')
                          end

            raise Thor::Error, "Service with type #{type} does not " \
                               "exist for app #{app.handle}. Valid " \
                               "types: #{valid_types}."
          end

          service
        end

        def apps_from_handle(handle, environment)
          # TODO: This should probably use each_app for more efficiency.
          if environment
            environment.apps
          else
            Aptible::Api::App.all(token: fetch_token)
          end.select { |a| a.handle == handle }
        end

        def extract_env(args)
          Hash[args.map do |arg|
            k, v = arg.split('=', 2)
            validate_env_key!(k)
            validate_env_pair!(k, v)
            [k, v]
          end]
        end

        def validate_env_key!(k)
          # Keys that start with '-' are likely to be mispelled options. As of
          # May 2017 (> 3 years of Aptible!), there are only 2 such cases, both
          # of which are indeed mispelled options.
          raise Thor::Error, "Invalid argument: #{k}" if k.start_with?('-')
        end

        def validate_env_pair!(k, v)
          # Nil values
          raise Thor::Error, "Invalid argument: #{k}" if v.nil?
        end

        private

        def handle_strategies
          [OptionsHandleStrategy, GitRemoteHandleStrategy]
        end
      end
    end
  end
end
