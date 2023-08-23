module Aptible
  module CLI
    module Subcommands
      module Maintenance
        def self.included(thor)
          thor.class_eval do
            include Helpers::Environment
            include Helpers::Maintenance
            include Helpers::Token

            desc 'maintenance:apps',
                 'List Apps impacted by maintenance schedules where '\
                 'restarts are required'
            option :environment
            define_method 'maintenance:apps' do
              found_maintenance = false
              m = maintenance_apps
              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'label'
                ) do |node|
                  scoped_environments(options).each do |account|
                    m.select { |app| app.account.id == account.id }
                     .each do |app|
                      next unless app.maintenance_deadline
                      found_maintenance = true
                      node.object do |n|
                        ResourceFormatter.inject_maintenance(
                          n,
                          'aptible restart --app',
                          app,
                          account
                        )
                      end
                    end
                  end
                end
              end
              if found_maintenance
                explanation 'app'
              else
                no_maintenances 'app'
              end
            end
            desc 'maintenance:dbs',
                 'List Databases impacted by maintenance schedules where '\
                 'restarts are required'
            option :environment
            define_method 'maintenance:dbs' do
              found_maintenance = false
              m = maintenance_databases
              Formatter.render(Renderer.current) do |root|
                root.grouped_keyed_list(
                  { 'environment' => 'handle' },
                  'label'
                ) do |node|
                  scoped_environments(options).each do |account|
                    m.select { |db| db.account.id == account.id }
                     .each do |db|
                      next unless db.maintenance_deadline
                      found_maintenance = true
                      node.object do |n|
                        ResourceFormatter.inject_maintenance(
                          n,
                          'aptible db:restart',
                          db,
                          account
                        )
                      end
                    end
                  end
                end
              end
              if found_maintenance
                explanation 'database'
              else
                no_maintenances 'database'
              end
            end
          end
        end

        def explanation(resource_type)
          CLI.logger.warn "\nYou may restart these #{resource_type}(s)"\
                          ' at any time, or Aptible will restart it'\
                          ' during the defined window.'
        end

        def no_maintenances(resource_type)
          CLI.logger.info "\nNo #{resource_type}s found affected "\
                          'by maintenance schedules.'
        end
      end
    end
  end
end
