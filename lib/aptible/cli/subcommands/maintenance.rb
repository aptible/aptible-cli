module Aptible
  module CLI
    module Subcommands
      module Maintenance
        def self.included(thor)
          thor.class_eval do
            include Helpers::Maintenance
            include Helpers::Token

            desc 'maintenance:apps', 
              'List Apps impacted by maintenance schedules'
            define_method 'maintenance:apps' do
              Formatter.render(Renderer.current) do |root|
                root.list do |node|
                  maintenance_apps.each do |app|
                    next unless app.maintenance_deadline
                    node.object do |n|
                      ResourceFormatter.inject_maintenance(n, app)
                    end
                  end
                end
              end
            end
            desc 'maintenance:databases',
              'List Databases impacted by maintenance schedules'
            define_method 'maintenance:databases' do
              Formatter.render(Renderer.current) do |root|
                root.list do |node|
                  maintenance_databases.each do |db|
                    next unless db.maintenance_deadline
                    node.object do |n|
                      ResourceFormatter.inject_maintenance(n, db)
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
