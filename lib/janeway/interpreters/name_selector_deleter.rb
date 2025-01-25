# frozen_string_literal: true

require_relative 'name_selector_interpreter'

module Janeway
  module Interpreters
    # Interprets a name selector, and deletes the matched values.
    class NameSelectorDeleter < NameSelectorInterpreter
      # Interpret selector on the given input.
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param _path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, _root, _path)
        return [] unless input.is_a?(Hash) && input.key?(name)

        [input.delete(name)]
      end

      # Return hash representation of this interpreter
      # @return [Hash]
      def as_json
        { type: type, value: name, next: @next&.as_json }
      end
    end
  end
end
