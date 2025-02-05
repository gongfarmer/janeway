# frozen_string_literal: true

require_relative 'array_slice_selector_interpreter'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Delete values that match the array slice selector and yield true from the block
    class ArraySliceSelectorDeleteIf < ArraySliceSelectorInterpreter
      include IterationHelper

      # @param node [AST::Expression]
      def initialize(node, &block)
        super(node)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Delete values at the indices matched by the array slice selector
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array]
      def interpret(input, _parent, _root, path)
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
          indexes.reverse_each do |i|
            next unless @yield_proc.call(input[i], input, path + [i])

            results << input.delete_at(i)
          end
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
