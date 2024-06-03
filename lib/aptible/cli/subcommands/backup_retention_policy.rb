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
                raise Thor::Error, "Environment #{env} does not have a " \
                                   'custom backup retention policy'
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
                 "Change the environemnt's backup retention policy"
            option :daily, type: :numeric,
                           desc: 'Number of daily backups to retain'
            option :monthly, type: :numeric,
                             desc: 'Number of monthly backups to retain'
            option :yearly, type: :numeric,
                            desc: 'Number of yearly backups to retain'
            option :make_copy, type: :boolean,
                               desc: 'If backup copies should be created'
            option(
              :keep_final,
              type: :boolean,
              desc: 'If final backups should be kept when databases are ' \
                    'deprovisioned'
            )
            define_method 'backup_retention_policy:set' do |env|
              if options.empty?
                raise Thor::Error,
                      'Please specify at least one attribute to change'
              end

              account = ensure_environment(environment: env)
              current_policy = account.backup_retention_policies.first

              # If an attribute isn't provided, use the value from the current
              # policy
              attrs = {}
              %i(daily monthly yearly make_copy keep_final).each do |a|
                opt = options[a]
                attrs[a] = opt.nil? ? current_policy.try(a) : opt
              end

              # If any of the attribues are missing, raise an error so that
              # we're not relying on the server's defaults
              if attrs.values.any?(&:nil?)
                raise Thor::Error, "Environemnt #{env} does not have a " \
                                   'custom backup retention policy. Please ' \
                                   'specify all attributes to create one.'
              end

              new_policy = account.create_backup_retention_policy!(**attrs)

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  ResourceFormatter.inject_backup_retention_policy(
                    node, new_policy.reload, account
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
