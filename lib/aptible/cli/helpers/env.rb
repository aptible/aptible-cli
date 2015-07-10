module Aptible
  module CLI
    module Helpers
      module Env
        def set_env(key, value)
          ENV[key] = value
        end
      end
    end
  end
end
