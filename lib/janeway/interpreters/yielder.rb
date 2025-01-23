# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Yields each input value.
    # It is inserted at the end of the "real" selectors in the AST, to receive and yield the output.
    # This is a supporting class for the supports the Janeway.each method.
    #
    # This will get pushed onto the end of the query AST.
    # Currently it must act like both an AST node and an interpreter.
    # This will be simpler if TODO some day may the interpreter subclass methods can be merged into the AST classes
    class Yielder < Base
      # The implicit constructor forwards a closure to the base class constructor.
      # Base class constructor stores it in @node.
      def initialize(&block)
        super(Struct.new(:next).new)
        @block = block
      end

      # Yield each input value
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @yieldparam [Object] matched value
      # @return [Object] input
      def interpret(input, parent, _root)
        @block.call(input, parent)
        input.is_a?(Array) ? input : [input]
      end
    end
  end
end
