module Aptible
  module CLI
    module Formatter
      class KeyedObject < Object
        # KeyedObject is rendered as an Object, but flags a given key as being
        # more important. Renderers may opt to only render this key.
        attr_reader :key

        def initialize(key)
          @key = key
          super()
        end
      end
    end
  end
end
