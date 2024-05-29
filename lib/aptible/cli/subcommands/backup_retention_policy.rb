require 'term/ansicolor'
require 'uri'
require 'English'

module Aptible
  module CLI
    module Subcommands
      module BackupRetentionPolicy
        def self.included(thor)
          thor.class_eval do
            include Helpers::Environment
            include Term::ANSIColor

            desc 'backup_retention_policy [ENVIRONMENT_HANDLE]',
                 'Show the current backup retention policy for the environment'
            define_method 'backup_retention_policy' do |env|
              account = ensure_environment(environment: env)
              policy = account.backup_retention_policies.first
              unless policy
                # Show the default policy
                policy = Aptible::Api::BackupRetentionPolicy.new
                policy.attributes[:id] = 'default'
                policy.attributes[:daily] = 90
                policy.attributes[:monthly] = 72
                policy.attributes[:yearly] = 0
                policy.attributes[:make_copy] = true
                policy.attributes[:keep_final] = true
              end

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  ResourceFormatter.inject_backup_retention_policy(
                    node, policy, account
                  )
                end
              end
            end

            desc 'backup_retention_policy:set [ENVIRONMENT_HANDLE] ' \
                 '[--daily DAILY_BACKUPS] [--monthly MONTHLY_BACKUPS] ' \
                 '[--yearly YEARLY_BACKUPS] [--make-copy|--no-make-copy] ' \
                 '[--keep-final|--no-keep-final]',
                 "Set the environemnt's backup retention policy"
            option :daily, type: :numeric,
                           desc: 'Number of daily backups to retain',
                           default: 90
            option :monthly, type: :numeric,
                             desc: 'Number of monthly backups to retain',
                             default: 72
            option :yearly, type: :numeric,
                            desc: 'Number of yarly backups to retain',
                            default: 0
            option :make_copy, type: :boolean,
                               desc: 'If backup copies should be created',
                               default: true
            option(
              :keep_final,
              type: :boolean,
              desc: 'If final backups should be kept when databases are '\
                    'deprovisioned',
              default: true
            )
            define_method 'backup_retention_policy:set' do |env|
              account = ensure_environment(environment: env)
              policy = account.create_backup_retention_policy!(**options)

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  ResourceFormatter.inject_backup_retention_policy(
                    node, policy.reload, account
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
