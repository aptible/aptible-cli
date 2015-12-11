require 'shellwords'
require 'pry'

module Aptible
  module CLI
    module Subcommands
      module Domains
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::App

            desc 'domains', "Print an app's current virtual domains"
            option :app
            option :remote, aliases: '-r'
            def domains
              app = ensure_app(options)
              print_vhosts(app) do |vhost|
                vhost.virtual_domain
              end
            end

            desc 'domains:hostnames', "Print an app's hostnames"
            option :app
            option :remote, aliases: '-r'
            define_method 'domains:hostnames' do
              app = ensure_app(options)
              print_vhosts(app) do |vhost|
                "#{vhost.virtual_domain} -> #{vhost.external_host}"
              end
            end

            private

            def print_vhosts(app)
              (app.vhosts || []).each do |vhost|
                say yield(vhost)
              end
            end
          end
        end
      end
    end
  end
end
