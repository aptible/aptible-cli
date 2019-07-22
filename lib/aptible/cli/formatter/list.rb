module Aptible
  module CLI
    module Formatter
      class List < Node
        attr_reader :children

        def initialize
          @children = []
        end

        def value(s)
          # TODO: Fail if block?
          @children << Value.new(s)
          nil
        end

        def object
          o = Object.new
          yield o
          @children << o
          nil
        end

        def list
          l = List.new
          yield l
          @children << l
          nil
        end
      end
    end
  end
end
