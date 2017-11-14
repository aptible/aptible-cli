module Aptible
  module CLI
    module Formatter
      class KeyedList < List
        # KeyedList is a list of objects with one key that is more important
        # than the others. Some renderers may opt to only display this key when
        # rendering the list.
        attr_reader :key

        def initialize(key)
          @key = key
          super()
        end

        def value(_)
          raise "not supported on #{self.class}"
        end

        def list
          raise "not supported on #{self.class}"
        end
      end
    end
  end
end
