module Aptible
  module CLI
    module Renderer
      class Json < Base
        def visit(node)
          case node
          when Formatter::Root
            visit(node.root)
          when Formatter::Object
            Hash[node.children.each_pair.map { |k, c| [k, visit(c)] }]
          when Formatter::List
            node.children.map { |c| visit(c) }
          when Formatter::Value
            node.value
          else
            raise "Unhandled node: #{node.inspect}"
          end
        end

        def render(node)
          JSON.pretty_generate(visit(node))
        end
      end
    end
  end
end
