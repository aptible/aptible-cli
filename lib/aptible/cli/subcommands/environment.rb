module Aptible
  module CLI
    module Subcommands
      module Environment
        def self.included(thor)
          thor.class_eval do
            include Helpers::Environment
            include Helpers::Token

            desc 'environment:list', 'List all environments'
            option :environment
            define_method 'environment:list' do
              Formatter.render(Renderer.current) do |root|
                root.keyed_list(
                  'handle'
                ) do |node|
                  scoped_environments(options).each do |account|
                    node.object do |n|
                      ResourceFormatter.inject_account(n, account)
                    end
                  end
                end
              end
            end

            desc 'environment:ca_cert',
                 'Retrieve the CA certificate associated with the environment'
            option :environment
            define_method 'environment:ca_cert' do
              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  'handle',
                  'ca_body'
                ) do |node|
                  scoped_environments(options).each do |account|
                    node.object do |n|
                      n.value('ca_body', account.ca_body)
                      ResourceFormatter.inject_account(n, account)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
