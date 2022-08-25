module Aptible
  module CLI
    module Helpers
      module ConfigPath
        def aptible_config_path
          ENV['APTIBLE_CONFIG_PATH'] || (File.join ENV['HOME'], '.aptible')
        end
      end
    end
  end
end
