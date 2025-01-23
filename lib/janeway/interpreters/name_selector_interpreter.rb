# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets a name selector, returns results or forwards them to next selector
    #
    # Filters the input by returning the key that has the given name.
    #
    # Must differentiate between a null value of a key that exists (nil)
    # and a key that does not exist ([])
    class NameSelectorInterpreter < Base
      alias selector node

      # Interpret selector on the given input.
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, root, path)
        return [] unless input.is_a?(Hash) && input.key?(selector.name)

        result = input[selector.name]
        return [result] unless @next

        # Forward result to next selector
        @next.interpret(result, input, root, path + [selector.name])
      end
    end
  end
end
