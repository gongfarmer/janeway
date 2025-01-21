# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets array slice selector on the given input
    class ArraySliceSelectorInterpreter < Base
      alias selector node

      # Filter the input by applying the array slice selector.
      #
      # @param selector [ArraySliceSelector]
      # @param input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @return [Array]
      def interpret(input, root)
        return [] unless input.is_a?(Array)
        return [] if selector&.step&.zero? # RFC: When step is 0, no elements are selected.

        # Calculate the upper and lower indices of the target range
        lower = selector.lower_index(input.size)
        upper = selector.upper_index(input.size)

        # Collect values from target indices. Omit the value from the final index.
        results =
          if selector.step.positive?
            lower.step(to: upper - 1, by: selector.step).map { input[_1] }
          else
            upper.step(to: lower + 1, by: selector.step).map { input[_1] }
          end
        return results unless @next

        # Apply child selector to each node in the output node list
        node_list = results
        results = []
        node_list.each do |node|
          results.concat @next.interpret(node, root)
        end
        results
      end
    end
  end
end
