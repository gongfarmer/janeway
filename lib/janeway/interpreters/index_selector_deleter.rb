# frozen_string_literal: true

require_relative 'name_selector_interpreter'

module Janeway
  module Interpreters
    # Interprets an index selector, and deletes the matched value.
    class IndexSelectorDeleter < IndexSelectorInterpreter
      # Interpret selector on the given input.
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param _path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, _root, _path)
        return [] unless input.is_a?(Array)

        index = selector.value
        result = input.fetch(index) # raises IndexError if no such index
        input.delete_at(index) # returns nil if deleted value is nil, or if no value was deleted
        [result]
      rescue IndexError
        []
      end
    end
  end
end
