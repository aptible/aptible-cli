module Aptible
  module CLI
    module Subcommands
      module Deploy
        DOCKER_IMAGE_DEPLOY_ARGS = Hash[%w(
          APTIBLE_DOCKER_IMAGE
          APTIBLE_PRIVATE_REGISTRY_EMAIL
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

            desc 'deploy [OPTIONS] [VAR1=VAL1] [VAR2=VAL2] [...]',
                 'Deploy an app'
            option :git_commitish,
                   desc: 'Deploy a specific git commit or branch: the ' \
                         'commitish must have been pushed to Aptible beforehand'
            option :git_detach,
                   type: :boolean, default: false,
                   desc: 'Detach this app from its git repository: ' \
                         'its Procfile, Dockerfile, and .aptible.yml will be ' \
                         'ignored until you deploy again with git'
            DOCKER_IMAGE_DEPLOY_ARGS.each_pair do |opt, var|
              option opt,
                     type: :string, banner: var,
                     desc: "Shorthand for #{var}=..."
            end
            app_options
            def deploy(*args)
              app = ensure_app(options)

              git_ref = options[:git_commitish]
              if options[:git_detach]
                if git_ref
                  raise Thor::Error, 'The options --git-committish and ' \
                                     '--git-detach are incompatible'
                end
                git_ref = NULL_SHA1
              end

              env = extract_env(args)

              DOCKER_IMAGE_DEPLOY_ARGS.each_pair do |opt, var|
                val = options[opt]
                next unless val
                if env[var] && env[var] != val
                  dasherized = "--#{opt.to_s.tr('_', '-')}"
                  raise Thor::Error, "The options #{dasherized} and #{var} " \
                                     'cannot be set to different values'
                end
                env[var] = val
              end

              opts = {
                type: 'deploy',
                env: env,
                git_ref: git_ref
              }.delete_if { |_, v| v.nil? || v.empty? }

              allow_it = [
                opts[:git_ref],
                opts[:env].try(:[], 'APTIBLE_DOCKER_IMAGE'),
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
