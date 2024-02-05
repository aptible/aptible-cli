module Aptible
  module CLI
    module Subcommands
      module Init
        def self.included(thor)
          thor.class_eval do
            include Helpers::App
            include Helpers::Environment
            include Helpers::Token

            desc 'init', 'First time setup of a code repository'
            def init
              CLI.logger.info "INIT YES NO"
            end
          end
        end
      end
    end
  end
end
