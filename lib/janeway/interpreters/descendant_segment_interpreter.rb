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
      # @return [Array<AST::Expression>] node list
      def interpret(input, parent, root)
        visit(input, parent) do |node, parent_of_node|
          @next.interpret(node, parent_of_node, root)
        end
      end

      # Visit all descendants of `input`.
      # Return results of applying `action` on each.
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      def visit(input, parent, &action)
        results = [yield(input, parent)]

        case input
        when Array
          results.concat(input.map { |elt| visit(elt, input, &action) })
        when Hash
          results.concat(input.values.map { |value| visit(value, input, &action) })
        else
          input
        end

        results.flatten(1).compact
      end
    end
  end
end
