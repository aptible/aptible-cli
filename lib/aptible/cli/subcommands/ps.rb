require 'shellwords'

module Aptible
  module CLI
    module Subcommands
      module Ps
        def self.included(thor)
          thor.class_eval do
            desc 'ps', 'DEPRECATED'
            def ps
              deprecated('This command no longer available.')
            end
          end
        end
      end
    end
  end
end
