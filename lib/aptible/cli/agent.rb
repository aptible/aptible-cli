require 'aptible/auth'
require 'thor'
require 'json'

require_relative 'helpers/token'
require_relative 'helpers/operation'
require_relative 'helpers/account'
require_relative 'helpers/app'
require_relative 'helpers/env'

require_relative 'subcommands/apps'
require_relative 'subcommands/config'
require_relative 'subcommands/db'
require_relative 'subcommands/domains'
require_relative 'subcommands/logs'
require_relative 'subcommands/ps'
require_relative 'subcommands/rebuild'
require_relative 'subcommands/restart'
require_relative 'subcommands/ssh'

module Aptible
  module CLI
    class Agent < Thor
      include Thor::Actions

      include Helpers::Token
      include Subcommands::Apps
      include Subcommands::Config
      include Subcommands::DB
      include Subcommands::Domains
      include Subcommands::Logs
      include Subcommands::Ps
      include Subcommands::Rebuild
      include Subcommands::Restart
      include Subcommands::SSH

      # Forward return codes on failures.
      def self.exit_on_failure?
        true
      end

      desc 'version', 'Print Aptible CLI version'
      def version
        puts "aptible-cli v#{Aptible::CLI::VERSION}"
      end

      desc 'login', 'Log in to Aptible'
      option :email
      option :password
      def login
        email = options[:email] || ask('Email: ')
        password = options[:password] || ask('Password: ', echo: false)
        puts ''

        begin
          token = Aptible::Auth::Token.create(email: email, password: password)
        rescue OAuth2::Error
          raise Thor::Error, 'Could not authenticate with given credentials'
        end

        save_token(token.access_token)
        puts "Token written to #{token_file}"
      end
    end
  end
end
