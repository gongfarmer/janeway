# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets a filter selector, and deletes matching values
    class FilterSelectorDeleter < FilterSelectorInterpreter
      # Interpret selector on the input.
      # @param input [Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_hash(input, root, _path)
        # Apply filter expressions to the input data
        results = []
        input.each do |key, value|
          # Run filter and interpret result
          result = @expr.interpret(value, nil, root, [])
          case result
          when TrueClass then results << value # comparison test - pass
          when FalseClass then next # comparison test - fail
          when Array
            next if result.empty?

            results << value # existence test - node list
          else
            results << value # existence test. Null values here == success.
          end
          input.delete(key)
        end
        results
      end

      # Interpret selector on the input.
      # @param input [Array] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_array(input, root, _path)
        # Apply filter expressions to the input data
        results = []

        # Iterate in reverse order so that deletion does not alter the remaining indexes
        i = input.size
        input.reverse_each do |value|
          i -= 1 # calculate array index

          # Run filter and interpret result
          result = @expr.interpret(value, nil, root, [])
          case result
          when TrueClass then results << value # comparison test - pass
          when FalseClass then next # comparison test - fail
          when Array
            next if result.empty?

            results << value # existence test - node list
          else
            results << value # existence test. Null values here == success.
          end
          input.delete_at(i)
        end
        results.reverse
      end
    end
  end
end
