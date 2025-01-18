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
      # @param root [Array, Hash] the entire input
      # @return [Array<AST::Expression>] node list
      def interpret(input, root)
        visit(input) do |node|
          @next.interpret(node, root)
        end
      end

      # Visit all descendants of `input`.
      # Return results of applying `action` on each.
      def visit(input, &action)
        results = [yield(input)]

        case input
        when Array
          results.concat(input.map { |elt| visit(elt, &action) })
        when Hash
          results.concat(input.values.map { |value| visit(value, &action) })
        else
          input
        end

        results.flatten(1).compact
      end
    end
  end
end
