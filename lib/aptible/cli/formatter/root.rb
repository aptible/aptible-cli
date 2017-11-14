module Aptible
  module CLI
    module Formatter
      class Root < Node
        attr_reader :root

        def initialize
          @root = nil
        end

        def value(s)
          assign_root(Value.new(s)) {}
        end

        def object(&block)
          assign_root(Object.new, &block)
        end

        def keyed_object(key, &block)
          assign_root(KeyedObject.new(key), &block)
        end

        def list(&block)
          assign_root(List.new, &block)
        end

        def keyed_list(key, &block)
          assign_root(KeyedList.new(key), &block)
        end

        def grouped_keyed_list(group, key, &block)
          assign_root(GroupedKeyedList.new(group, key), &block)
        end

        private

        def assign_root(node)
          raise "root has already been initialized: #{@root.inspect}" if @root
          yield node
          @root = node
          nil
        end
      end
    end
  end
end
