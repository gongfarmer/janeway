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

      # Visit all descendants of `input`.
      # Return results of applying `action` on each.
      # @param input [Array, Hash] the results of processing so far
      # @param path [Array<String>] elements of normalized path to the current input
      # @param parent [Array, Hash] parent of the input object
      def visit(input, parent, path, &block)
        results = [yield(input, parent, path)]

        case input
        when Array
          results.concat(input.map.with_index { |value, i| visit(value, input, path + [i], &block) })
        when Hash
          results.concat(input.map { |key, value| visit(value, input, path + [key], &block) })
        end
        # basic types are ignored, they will be added by one of the above

        results.flatten(1)
      end
    end
  end
end
