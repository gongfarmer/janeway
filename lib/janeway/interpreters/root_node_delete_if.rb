# frozen_string_literal: true

require_relative 'root_node_interpreter'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Delete values from the root node for which the block returns a truthy value.
    class RootNodeDeleteIf < RootNodeInterpreter
      include IterationHelper

      # @param node [AST::RootNode]
      def initialize(node, &block)
        super(node)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Delete values from the root container for which the block returns truthy.
      #
      # @param _input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param _path [Array<String>] elements of normalized path to the current input
      # @return [Array] deleted elements
      def interpret(_input, _parent, root, _path = nil)
        case root
        when Array then maybe_delete_array_values(root)
        when Hash then maybe_delete_hash_values(root)
        else []
        end
      end

      private

      # @param input [Array]
      def maybe_delete_array_values(input)
        results = []
        (input.size - 1).downto(0).each do |i|
          next unless @yield_proc.call(input[i], input, ['$', i])

          results << input.delete_at(i)
        end
        results.reverse
      end

      # @param input [Hash]
      def maybe_delete_hash_values(input)
        results = []
        input.each do |key, value|
          next unless @yield_proc.call(value, input, ['$', key])

          results << input.delete(key)
        end
        results
      end
    end
  end
end
