module Aptible
  module CLI
    module Subcommands
      module Deploy
        DEPRECATED_ENV = Hash[%w(
          APTIBLE_DOCKER_IMAGE
          APTIBLE_PRIVATE_REGISTRY_USERNAME
          APTIBLE_PRIVATE_REGISTRY_PASSWORD
        ).map do |var|
          opt = var.gsub(/^APTIBLE_/, '').downcase.to_sym
          [opt, var]
        end]

        NULL_SHA1 = '0000000000000000000000000000000000000000'.freeze

        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App
            include Helpers::Telemetry

            desc 'deploy [--app APP] [OPTIONS] [VAR1=VAL1] [VAR2=VAL2] [...]',
                 'Deploy an app'
            option :git_commitish,
                   desc: 'Deploy a specific git commit or branch: the ' \
                         'commitish must have been pushed to Aptible beforehand'
            option :git_detach,
                   type: :boolean, default: false,
                   desc: 'Detach this app from its git repository: ' \
                         'its Procfile, Dockerfile, and .aptible.yml will be ' \
                         'ignored until you deploy again with git'
            option :container_count, type: :numeric,
                                     desc: 'This option only affects new ' \
                                           'services, not existing ones.'
            option :container_size, type: :numeric,
                                    desc: 'This option only affects new ' \
                                           'services, not existing ones.'
            option :container_profile, type: :string,
                                       desc: 'This option only affects new ' \
                                             'services, not existing ones. ' \
                                             'Examples: m c r'

            option :docker_image,
                   type: :string,
                   desc: 'The docker image to deploy. If none specified, ' \
                         'the currently deployed image will be pulled again'
            option :private_registry_username,
                   type: :string,
                   desc: 'Username for Docker images located in a private ' \
                        'repository'
            option :private_registry_password,
                   type: :string,
                   desc: 'Password for Docker images located in a private ' \
                         'repository'
            option :private_registry_email,
                   type: :string,
                   desc: 'This parameter is deprecated'

            app_options
            def deploy(*args)
              telemetry(__method__, options)

              app = ensure_app(options)

              git_ref = options[:git_commitish]
              if options[:git_detach]
                if git_ref
                  raise Thor::Error, 'The options --git-commitish and ' \
                                     '--git-detach are incompatible'
                end
                git_ref = NULL_SHA1
              end

              env = extract_env(args)

              DEPRECATED_ENV.each_pair do |opt, var|
                val = options[opt]
                dasherized = "--#{opt.to_s.tr('_', '-')}"
                if env[var]
                  m = "WARNING: The environment variable #{var} " \
                      'will be deprecated. Use the option ' \
                      "#{dasherized}, instead."
                  CLI.logger.warn m
                end
                next unless val
                if env[var] && env[var] != val
                  raise Thor::Error, "The options #{dasherized} and #{var} " \
                                     'cannot be set to different values'
                end
              end

              settings = {}
              sensitive_settings = {}

              if options[:docker_image]
                settings['APTIBLE_DOCKER_IMAGE'] = options[:docker_image]
              end

              if options[:private_registry_username]
                sensitive_settings['APTIBLE_PRIVATE_REGISTRY_USERNAME'] =
                  options[:private_registry_username]
              end
              if options[:private_registry_password]
                sensitive_settings['APTIBLE_PRIVATE_REGISTRY_PASSWORD'] =
                  options[:private_registry_password]
              end

              opts = {
                type: 'deploy',
                env: env,
                settings: settings,
                sensitive_settings: sensitive_settings,
                git_ref: git_ref,
                container_count: options[:container_count],
                container_size: options[:container_size],
                instance_profile: options[:container_profile]
              }.delete_if { |_, v| v.nil? || v.try(:empty?) }

              allow_it = [
                opts[:git_ref],
                opts[:settings].try(:[], 'APTIBLE_DOCKER_IMAGE'),
                app.status == 'provisioned'
              ].any? { |x| x }

              unless allow_it
                m = 'You need to deploy either from git or a Docker image'
                raise Thor::Error, m
              end

              operation = app.create_operation!(opts)

              CLI.logger.info 'Deploying app...'
              attach_to_operation_logs(operation)
            end
          end
        end
      end
    end
  end
end
