# frozen_string_literal: true

require_relative 'name_selector_interpreter'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Interprets a name selector, and deletes the matched values if the block returns a truthy value.
    class NameSelectorDeleteIf < NameSelectorInterpreter
      include IterationHelper

      # @param selector [AST::NameSelector]
      def initialize(selector, &block)
        super(selector)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Interpret selector on the given input.
      # Delete matching value for which the block returns truthy value.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param path [Array] elements of normalized path to the current input
      def interpret(input, _parent, _root, path)
        return [] unless input.is_a?(Hash) && input.key?(name)
        return [] unless @yield_proc.call(input[name], input, path + [name])

        [input.delete(name)]
      end

      # Return hash representation of this interpreter
      # @return [Hash]
      def as_json
        { type: type, value: name }
      end
    end
  end
end
