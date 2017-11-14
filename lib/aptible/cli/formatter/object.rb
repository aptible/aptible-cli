module Aptible
  module CLI
    module Formatter
      class Object < Node
        attr_reader :children

        def initialize
          @children = {}
        end

        def value(k, v)
          @children[k] = Value.new(v)
          nil
        end

        def object(k)
          o = Object.new
          yield o
          @children[k] = o
          nil
        end

        def list(k)
          l = List.new
          yield l
          @children[k] = l
          nil
        end
      end
    end
  end
end
