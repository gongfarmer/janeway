# frozen_string_literal: true

require_relative 'root_node_interpreter'

module Janeway
  module Interpreters
    # Interprets the root node for deletion
    class RootNodeDeleter < RootNodeInterpreter
      # Delete all values from the root node.
      #
      # TODO: unclear, for deletion is there a difference between queries '$' and '$.*'?
      #
      # @param _input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param _path [Array<String>] elements of normalized path to the current input
      # @return [Array] deleted elements
      def interpret(_input, _parent, root, _path)
        case root
        when Array
          results = root.dup
          root.clear
          results
        when Hash
          results = root.values
          root.clear
          results
        else
          []
        end
      end
    end
  end
end
