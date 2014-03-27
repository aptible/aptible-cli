require 'thor'
require 'json'
require 'aptible/auth'

require_relative 'helpers/token'
require_relative 'helpers/operation'
require_relative 'helpers/app'

require_relative 'subcommands/config'

module Aptible
  module CLI
    class Agent < Thor
      include Thor::Actions

      include Helpers::Token
      include Subcommands::Config

      desc 'version', 'Print Aptible CLI version'
      def version
        puts "aptible-cli v#{Aptible::CLI::VERSION}"
      end

      desc 'login', 'Log in to Aptible'
      def login
        email = ask('Email: ')
        password = ask('Password: ', echo: false)
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
