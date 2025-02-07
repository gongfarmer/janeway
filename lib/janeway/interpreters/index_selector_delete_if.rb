# frozen_string_literal: true

require_relative 'index_selector_interpreter'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Interprets an index selector, and deletes the matched value if the block returns true.
    class IndexSelectorDeleteIf < IndexSelectorInterpreter
      include IterationHelper

      # @param selector [AST::IndexSelector]
      def initialize(selector, &block)
        super(selector)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Interpret selector on the given input.
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, _root, path)
        return [] unless input.is_a?(Array)

        index = selector.value
        result = input.fetch(index) # raises IndexError if no such index
        index += input.size if index.negative? # yield positive index for the normalize path
        return unless @yield_proc.call(input[index], input, path + [index])

        index += input.size if index.negative?
        input.delete_at(index) # returns nil if deleted value is nil, or if no value was deleted
        [result]
      rescue IndexError
        []
      end
    end
  end
end
