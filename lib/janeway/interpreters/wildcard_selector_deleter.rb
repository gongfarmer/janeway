# frozen_string_literal: true

require_relative 'wildcard_selector_interpreter'

module Janeway
  module Interpreters
    # Interprets a wildcard selector, and deletes the results.
    class WildcardSelectorDeleter < WildcardSelectorInterpreter
      # Delete all elements from the input
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param _path [Array<String>] elements of normalized path to the current input
      # @return [Array] deleted elements
      def interpret(input, _parent, _root, _path)
        case input
        when Array
          results = input.dup
          input.clear
          results
        when Hash
          results = input.values
          input.clear
          results
        else
          []
        end
      end
    end
  end
end
