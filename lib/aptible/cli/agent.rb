require 'aptible/auth'
require 'thor'
require 'json'

require_relative 'helpers/token'
require_relative 'helpers/operation'
require_relative 'helpers/app'

require_relative 'subcommands/config'
require_relative 'subcommands/ssh'
require_relative 'subcommands/tunnel'

module Aptible
  module CLI
    class Agent < Thor
      include Thor::Actions

      include Helpers::Token
      include Subcommands::Config
      include Subcommands::SSH
      include Subcommands::Tunnel

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
