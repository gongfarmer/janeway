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
      # @param root [Array, Hash] the entire input
      def interpret(input, root)
        return [] unless input.is_a?(Hash) && input.key?(selector.name)

        result = input[selector.name]
        return [result] unless @next

        # Forward result to next selector
        @next.interpret(result, root)
      end
    end
  end
end
