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
      # @param root [Array, Hash] the entire input
      def interpret(input, root)
        values =
          case input
          when Array then input
          when Hash then input.values
          else []
          end

        return values if values.empty? # early exit, no need for further processing on empty list
        return values unless @next

        # Apply child selector to each node in the output node list
        results = []
        values.each do |value|
          results.concat @next.interpret(value, root)
        end
        results
      end
    end
  end
end
