module Aptible
  module CLI
    module Renderer
      class Text < Base
        include ActiveSupport::Inflector

        POST_PROCESSED_KEYS = {
          'Tls' => 'TLS',
          'Dns' => 'DNS',
          'Ip' => 'IP'
        }.freeze

        def visit(node, io)
          case node
          when Formatter::Root
            visit(node.root, io)
          when Formatter::KeyedObject
            visit(node.children.fetch(node.key), io)
          when Formatter::Object
            node.children.each_pair do |k, c|
              io.print "#{format_key(k)}: "
              visit(c, io)
            end
          when Formatter::GroupedKeyedList
            groups = node.children.group_by { |n| n.children.fetch(node.group) }
            enum = spacer_enumerator
            groups.each_pair.sort_by(&:first).each do |key, group|
              io.print enum.next
              io.print '=== '
              visit(key, io)
              output_list(group.map { |n| n.children.fetch(node.key) }, io)
            end
          when Formatter::KeyedList
            nodes = node.children.map { |n| n.children.fetch(node.key) }
            output_list(nodes, io)
          when Formatter::List
            output_list(node.children, io)
          when Formatter::Value
            io.puts node.value
          else
            raise "Unhandled node: #{node.inspect}"
          end
        end

        def render(node)
          io = StringIO.new
          visit(node, io)
          io.rewind
          io.read
        end

        private

        def output_list(nodes, io)
          if nodes.all? { |v| v.is_a?(Formatter::Value) }
            # All nodes are single values, so we render one per line.
            nodes.each { |c| visit(c, io) }
          else
            # Nested values. Display each as a block with newlines in between.
            enum = spacer_enumerator
            nodes.each do |c|
              io.print enum.next
              visit(c, io)
            end
          end
        end

        def format_key(key)
          key = titleize(humanize(key))
          POST_PROCESSED_KEYS.each_pair do |pk, pv|
            key = key.gsub(/(^|\W)#{Regexp.escape(pk)}($|\W)/, "\\1#{pv}\\2")
          end
          key
        end

        def spacer_enumerator
          Enumerator.new do |y|
            y << ''
            loop { y << "\n" }
          end
        end
      end
    end
  end
end
