# frozen_string_literal: true

require_relative 'filter_expression_base'

module Janeway
  module Interpreters
    # Interpets current node identifier.
    # This applies the following selector to the input.
    class CurrentNodeInterpreter < FilterExpressionBase
      alias current_node node

      # Apply selector to each value in the current node and return result.
      #
      # The result is an Array containing all results of evaluating the CurrentNode's selector (if any.)
      #
      # If the selector extracted values from nodes such as strings, numbers or nil/null,
      # these will be included in the array.
      # If the selector did not match any node, the array may be empty.
      # If there was no selector, then the current input node is returned in the array.
      #
      # @param _input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @return [Array] Node List containing all results from evaluating this node's selectors.
      def interpret(input, root)
        if @next
          @next.interpret(input, root)
        else
          input
        end
      end
    end
  end
end
