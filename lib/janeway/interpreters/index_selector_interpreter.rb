# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets an index selector, returns results or forwards them to next selector
    #
    # Filter the input by returning the array element with the given index.
    # Return empty list if input is not an array, or if array does not contain index.
    #
    # Output is an array because all selectors must return node lists, even if
    # they only select a single element.
    #
    # @param selector [IndexSelector]
    # @param input [Array]
    # @return [Array]
    class IndexSelectorInterpreter < Base
      alias selector node

      # Interpret an index selector on the given input.
      # NOTHING is selected, and it is not an error, if the index lies outside the range of the array.
      # NOTHING is selected from a value that is not an array.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, root, path)
        return [] unless input.is_a?(Array)

        result = input.fetch(selector.value) # raises IndexError if no such index
        return [result] unless @next

        index = selector.value
        index += input.size if index.negative?
        @next.interpret(result, input, root, path + [index])
      rescue IndexError
        []
      end
    end
  end
end
