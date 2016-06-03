require 'aptible/api'
require 'git'

module Aptible
  module CLI
    module Helpers
      module App
        include Helpers::Token
        include Helpers::Environment

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

        def self.included(base)
          base.extend ClassMethods
        end

        module ClassMethods
          def app_options
            option :app
            option :environment
            option :remote, aliases: '-r'
          end
        end

        def ensure_app(options = {})
          remote = options[:remote] || ENV['APTIBLE_REMOTE'] || 'aptible'
          app_handle = options[:app] || handles_from_remote(remote)[:app_handle]
          environment_handle = options[:environment] ||
                               handles_from_remote(remote)[:environment_handle]

          unless app_handle
            fail Thor::Error, <<-ERR.gsub(/\s+/, ' ').strip
              Could not find app in current working directory, please specify
              with --app
            ERR
          end

          environment = environment_from_handle(environment_handle)
          if environment_handle && !environment
            fail Thor::Error, "Could not find environment #{environment_handle}"
          end
          apps = apps_from_handle(app_handle, environment)
          case apps.count
          when 1
            return apps.first
          when 0
            err_bits = ["Could not find app #{app_handle}"]

            if environment_handle
              err_bits << "in environment #{environment_handle}"
              unless options[:environment]
                # We guessed the environment, and our guess might have been
                # wrong, let the user know.
                err_bits << '(NOTE: environment was derived from git remote ' \
                            "#{remote}, use --environment to override)"
              end
            end
            fail Thor::Error, err_bits.join(' ')
          else
            fail Thor::Error, 'Multiple apps exist, please specify environment'
          end
        end

        def apps_from_handle(handle, environment)
          if environment
            apps = environment.apps
          else
            apps = Aptible::Api::App.all(token: fetch_token)
          end
          apps.select { |a| a.handle == handle }
        end

        def handles_from_remote(remote_name)
          git = Git.open(Dir.pwd)
          aptible_remote = git.remote(remote_name).url || ''
          HandleFromGitRemote.parse(aptible_remote)
        rescue
          {}
        end
      end
    end
  end
end
