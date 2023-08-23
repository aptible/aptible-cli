require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Maintenance
        include Helpers::Token

        def maintenance_apps
          Aptible::Api::MaintenanceApp.all(token: fetch_token)
        end

        def maintenance_databases
          Aptible::Api::MaintenanceDatabase.all(token: fetch_token)
        end
      end
    end
  end
end
