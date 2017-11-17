module Aptible
  module CLI
    module Formatter
      class Object < Node
        attr_reader :children

        def initialize
          @children = {}
        end

        def value(k, v)
          assign_child(k, Value.new(v)) {}
        end

        def object(k, &block)
          assign_child(k, Object.new, &block)
        end

        def keyed_object(k, object_key, &block)
          assign_child(k, KeyedObject.new(object_key), &block)
        end

        def list(k, &block)
          assign_child(k, List.new, &block)
        end

        private

        def assign_child(k, node)
          raise "Overwriting keys (#{k}) is not allowed" if @children[k]
          yield node
          @children[k] = node
          nil
        end
      end
    end
  end
end
