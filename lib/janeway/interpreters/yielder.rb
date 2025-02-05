# frozen_string_literal: true

require_relative 'base'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Yields each input value.
    #
    # This is inserted at the end of the "real" selectors in the AST, to receive and yield the output.
    # This is a supporting class for the Janeway.each method.
    class Yielder
      include IterationHelper

      def initialize(&block)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Yield each input value
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param path [Array<String, Integer>] components of normalized path to the current input
      # @yieldparam [Object] matched value
      # @return [Object] input as node list
      def interpret(input, parent, _root, path)
        @yield_proc.call(input, parent, path)
        input.is_a?(Array) ? input : [input]
      end

      # Dummy method from Interpreters::Base, allow child segment interpreter to disable the
      # non-exist 'next' link.
      # @return [void]
      def next=(*); end

      # @return [Hash]
      def as_json
        { type: self.class.to_s.split('::').last }
      end
    end
  end
end
