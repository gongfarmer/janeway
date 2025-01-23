# frozen_string_literal: true

require_relative 'base'
require_relative '../normalized_path'

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
            # Yield values only to an enumerator.
            proc { |input, _parent, _path| @block.call(input) }
          elsif block.arity >= 3
            # Only do the work of constructing the normalized path when it is actually used
            proc { |input, parent, path| @block.call(input, parent, normalized_path(path)) }
          else
            proc { |input, parent, _path| @block.call(input, parent) }
          end
      end

      # Yield each input value
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param path_componenets [Array<String>] components of normalized path to the current input
      # @yieldparam [Object] matched value
      # @return [Object] input as node list
      def interpret(input, parent, _root, path)
        @yield_to_block.call(input, parent, path)
        input.is_a?(Array) ? input : [input]
      end

      # Convert the list of path elements into a normalized query string.
      #
      # This form uses a subset of jsonpath that unambiguously points to a value
      # using only name and index selectors.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-normalized-paths
      #
      # Name selectors must use bracket notation, not shorthand.
      #
      # @param components [Array<String, Integer>]
      # @return [String]
      def normalized_path(components)
        # First component is the root identifer, the remaining components are
        # all index selectors or name selectors.
        # Handle the root identifier separately, because .normalize does not handle those.
        '$' + components[1..].map { NormalizedPath.normalize(_1) }.join
      end
    end
  end
end
