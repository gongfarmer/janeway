# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Find all descendants of the current input that match the selector in the DescendantSegment
    class DescendantSegmentInterpreter < Base
      alias descendant_segment node

      # Find all descendants of the current input that match the selector in the DescendantSegment
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array<AST::Expression>] node list
      def interpret(input, parent, root, path)
        visit(input, parent, path) do |node, parent_of_node, sub_path|
          @next.interpret(node, parent_of_node, root, sub_path)
        end
      end

      # Visit all descendants of `input` and concatenate the results of
      # `block` at each node. Iterative depth-first pre-order — a recursive
      # implementation would risk SystemStackError on deep JSON and allocated
      # an array-per-node plus a flatten pass.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param path [Array<String>] elements of normalized path to the current input
      def visit(input, parent, path)
        results = []
        stack = [[input, parent, path]]
        until stack.empty?
          node, node_parent, node_path = stack.pop
          results.concat(yield(node, node_parent, node_path))

          case node
          when Array
            # Push in reverse so the leftmost child is popped first (pre-order).
            i = node.size - 1
            while i >= 0
              stack.push([node[i], node, node_path + [i]])
              i -= 1
            end
          when Hash
            # Iterate to an array once so we can walk it in reverse.
            pairs = node.to_a
            i = pairs.size - 1
            while i >= 0
              k, v = pairs[i]
              stack.push([v, node, node_path + [k]])
              i -= 1
            end
          end
          # Basic (non-container) types have no descendants — nothing to push.
        end
        results
      end
    end
  end
end
