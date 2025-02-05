# frozen_string_literal: true

require_relative 'filter_selector_interpreter'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Interprets a filter selector by deleting matching values for which the block returns a truthy value
    class FilterSelectorDeleteIf < FilterSelectorInterpreter
      include IterationHelper

      # @param selector [AST::FilterSelector]
      def initialize(selector, &block)
        super(selector)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Interpret selector on the input.
      # @param input [Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_hash(input, root, path)
        # Apply filter expressions to the input data
        results = []
        input.each do |key, value|
          # Run filter and interpret result
          result = @expr.interpret(value, nil, root, [])
          case result
          when FalseClass then next # comparison test - fail
          when Array then next if result.empty?
          end

          # filter test passed, next yield value to block
          next unless @yield_proc.call(value, input, path + [key])

          results << input.delete(key)
        end
        results
      end

      # Interpret selector on the input.
      # @param input [Array] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_array(input, root, path)
        # Apply filter expressions to the input data
        results = []

        # Iterate in reverse order so that deletion does not alter the remaining indexes
        i = input.size
        input.reverse_each do |value|
          i -= 1 # calculate array index

          # Run filter and interpret result
          result = @expr.interpret(value, nil, root, [])
          case result
          when FalseClass then next # comparison test - fail
          when Array then next if result.empty?
          end

          # filter test passed, next yield value to block
          next unless @yield_proc.call(value, input, path + [i])

          results << input.delete_at(i)
        end
        results.reverse
      end
    end
  end
end
