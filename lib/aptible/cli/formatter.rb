require_relative 'formatter/node'
require_relative 'formatter/list'
require_relative 'formatter/keyed_list'
require_relative 'formatter/grouped_keyed_list'
require_relative 'formatter/object'
require_relative 'formatter/keyed_object'
require_relative 'formatter/root'
require_relative 'formatter/value'

module Aptible
  module CLI
    module Formatter
      def self.render(renderer)
        root = Root.new
        yield root
        out = renderer.render(root)
        puts out if out
      end
    end
  end
end
