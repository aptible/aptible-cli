module Aptible
  module CLI
    module Subcommands
      module Environment
        def self.included(thor)
          thor.class_eval do
            include Helpers::Environment
            include Helpers::Token
            include Helpers::Telemetry

            desc 'environment:list', 'List all environments'
            option :environment, aliases: '--env'
            define_method 'environment:list' do
              telemetry(__method__, options)

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
            option :environment, aliases: '--env'
            define_method 'environment:ca_cert' do
              telemetry(__method__, options)

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

            desc 'environment:rename OLD_HANDLE NEW_HANDLE',
                 'Rename an environment handle. In order for the new'\
                 ' environment handle to appear in log drain/metric'\
                 ' destinations, you must restart the apps/databases in'\
                 ' this environment.'
            define_method 'environment:rename' do |old_handle, new_handle|
              telemetry(__method__, options)

              env = ensure_environment(options.merge(environment: old_handle))
              env.update!(handle: new_handle)
              m1 = "In order for the new environment handle (#{new_handle})"\
                   ' to appear in log drain and metric drain destinations,'\
                   ' you must restart the apps and databases in this'\
                   ' environment. Also be aware of the following resources'\
                   ' that may need names adjusted:'
              m2 = "* Git remote URLs (ex: git@beta.aptible.com:#{new_handle}"\
                   '/APP_HANDLE.git)'
              m3 = '* Your own external scripts (e.g. for CI/CD)'
              [m1, m2, m3].each { |val| CLI.logger.info val }
            end
          end
        end
      end
    end
  end
end
