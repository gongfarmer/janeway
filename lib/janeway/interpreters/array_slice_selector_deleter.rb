# frozen_string_literal: true

require_relative 'array_slice_selector_interpreter'

module Janeway
  module Interpreters
    # Interprets array slice selector and deletes matching values
    class ArraySliceSelectorDeleter < ArraySliceSelectorInterpreter
      # Delete values at the indices matched by the array slice selector
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param _path [Array<String>] elements of normalized path to the current input
      # @return [Array]
      def interpret(input, _parent, _root, _path)
        return [] unless input.is_a?(Array)
        return [] if selector&.step&.zero? # RFC: When step is 0, no elements are selected.

        # Calculate the upper and lower indices of the target range
        lower = selector.lower_index(input.size)
        upper = selector.upper_index(input.size)

        # Convert bounds and step to index values.
        # Omit the final index, since no value is collected for that.
        # Delete indexes from largest to smallest, so that deleting an index does
        # not change the remaining indexes
        results = []
        if selector.step.positive?
          indexes = lower.step(to: upper - 1, by: selector.step).to_a
          indexes.reverse_each { |i| results << input.delete_at(i) }
          results.reverse
        else
          indexes = upper.step(to: lower + 1, by: selector.step).to_a
          indexes.each { |i| results << input.delete_at(i) }
          results
        end
      end
    end
  end
end
