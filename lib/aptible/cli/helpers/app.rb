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
  :((?<environment_handle>[0-9a-z\-_\.]+?)/)?(?<app_handle>[0-9a-z\-_\.]+)\.git
  \z
}x

          def self.parse(url)
            PATTERN.match(url)
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
          remote = options[:remote] || ENV['APTIBLE_REMOTE']
          handle = options[:app]
          if handle
            environment = ensure_environment(options)
          else
            handles = handle_from_remote(remote) || ensure_default_handle
            handle = handles[:app_handle]
            env_handle = handles[:environment_handle] || options[:environment]
            environment = ensure_environment(environment: env_handle)
          end

          app = app_from_handle(handle, environment)
          return app if app
          fail Thor::Error, "Could not find app #{handle}"
        end

        def app_from_handle(handle, environment)
          environment.apps.find do |a|
            a.handle == handle
          end
        end

        def ensure_default_handle
          return default_handle if default_handle
          fail Thor::Error, <<-ERR.gsub(/\s+/, ' ').strip
            Could not find app in current working directory, please specify
            with --app
          ERR
        end

        def default_handle
          handle_from_remote(:aptible)
        end

        def handle_from_remote(remote_name)
          git = Git.open(Dir.pwd)
          aptible_remote = git.remote(remote_name).url || ''
          HandleFromGitRemote.parse(aptible_remote)
        rescue
          nil
        end
      end
    end
  end
end
