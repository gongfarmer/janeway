# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets array slice selector on the given input
    class ArraySliceSelectorInterpreter < Base
      alias selector node

      # Filter the input by applying the array slice selector.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array]
      def interpret(input, _parent, root, path)
        return [] unless input.is_a?(Array)
        return [] if selector&.step&.zero? # RFC: When step is 0, no elements are selected.

        # Calculate the upper and lower indices of the target range
        lower = selector.lower_index(input.size)
        upper = selector.upper_index(input.size)

        # Collect real index values. Omit the final index, since no value is collected for that.
        indexes =
          if selector.step.positive?
            lower.step(to: upper - 1, by: selector.step).to_a
          else
            upper.step(to: lower + 1, by: selector.step).to_a
          end
        return indexes.map { |i| input[i] } unless @next

        # Apply child selector to each node in the output node list
        results = []
        indexes.each do |i|
          results.concat @next.interpret(input[i], input, root, path + [i])
        end
        results
      end
    end
  end
end
