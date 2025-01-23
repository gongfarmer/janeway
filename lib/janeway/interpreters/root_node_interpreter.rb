# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets the root identifer, returns results or forwards them to next selector.
    #
    # This is required at the beginning of every jsonpath query.
    # It may also be used within filter selector expressions.
    class RootNodeInterpreter < Base
      # Start an expression chain using the entire, unfiltered input.
      #
      # @param _input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret(_input, _parent, root, _path = nil)
        return [root] unless @next

        @next.interpret(root, nil, root, ['$'])
      end
    end
  end
end
