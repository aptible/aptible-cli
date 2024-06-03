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
                raise Thor::Error, 'Could not find backup retention policy ' \
                                   "for environment #{env}"
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
                           default: 1
            option :monthly, type: :numeric,
                             desc: 'Number of monthly backups to retain',
                             default: 0
            option :yearly, type: :numeric,
                            desc: 'Number of yearly backups to retain',
                            default: 0
            option :make_copy, type: :boolean,
                               desc: 'If backup copies should be created',
                               default: false
            option(
              :keep_final,
              type: :boolean,
              desc: 'If final backups should be kept when databases are '\
                    'deprovisioned',
              default: false
            )
            define_method 'backup_retention_policy:set' do |env|
              account = ensure_environment(environment: env)
              policy = account.create_backup_retention_policy!(
                daily: options[:daily],
                monthly: options[:monthly],
                yearly: options[:yearly],
                make_copy: options[:make_copy],
                keep_final: options[:keep_final]
              )

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
