# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets a wildcard selector, returns results or forwards them to next selector
    class WildcardSelectorInterpreter < Base
      alias selector node

      # Return values from the input.
      # For array, return the array.
      # For Hash, return hash values.
      # For anything else, return empty list.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, root, path)
        case input
        when Array then interpret_array(input, root, path)
        when Hash then interpret_hash(input, root, path)
        else []
        end
      end

      def interpret_hash(input, root, path)
        return [] if input.empty? # early exit, no need for further processing on empty list
        return input.values unless @next

        # Apply child selector to each node in the output node list
        results = []
        input.each do |key, value|
          results.concat @next.interpret(value, input, root, path + [key])
        end
        results
      end

      def interpret_array(input, root, path)
        return input if input.empty? # early exit, no need for further processing on empty list
        return input unless @next

        # Apply child selector to each node in the output node list
        results = []
        input.each_with_index do |value, i|
          results.concat @next.interpret(value, input, root, path + [i])
        end
        results
      end
    end
  end
end
