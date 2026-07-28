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
        return [] if effective_step.zero? # RFC: When step is 0, no elements are selected.

        # Delete matching indexes from largest to smallest so that deletion
        # does not shift the remaining indexes.
        indexes = index_range(input.size)
        results = []
        if effective_step.positive?
          indexes.reverse_each do |i|
            next unless @yield_proc.call(input[i], input, path + [i])

            results << input.delete_at(i)
          end
          results.reverse
        else
          indexes.each do |i|
            next unless @yield_proc.call(input[i], input, path + [i])

            results << input.delete_at(i)
          end
          results
        end
      end
    end
  end
end
