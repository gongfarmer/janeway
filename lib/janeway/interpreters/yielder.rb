# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Yields each input value.
    #
    # It is inserted at the end of the "real" selectors in the AST, to receive and yield the output.
    # This is a supporting class for the Janeway.each method.
    class Yielder
      def initialize(&block)
        @block = block

        # Decide how many parameters to yield to this block.
        # block.arity is -1 when no block was given, and an enumerator is being returned from #each
        @yield_to_block =
          if block.arity.negative?
            # Yield values only to an enum.
            proc { |input, _parent| @block.call(input) }
          else
            proc { |input, parent| @block.call(input, parent) }
          end
      end

      # Yield each input value
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @yieldparam [Object] matched value
      # @return [Object] input as node list
      def interpret(input, parent, _root)
        @yield_to_block.call(input, parent)
        input.is_a?(Array) ? input : [input]
      end
    end
  end
end
