# frozen_string_literal: true

require_relative 'tree_constructor'

module Janeway
  # Interpreters module contains interpreter classes which correspond to each
  # type of AST::Node.
  module Interpreters
    # Base class for interpreters.
    class Base
      # The special result NOTHING represents the absence of a JSON value and
      # is distinct from any JSON value, including null.
      # It represents:
      #  * object keys referred to by name that do not exist in the input
      #  * array values referred to by index that are out of range
      #  * return value of function calls with an invalid input data type
      NOTHING = :nothing

      # Subsequent expression interpreter that filters the output of this one
      # @return [Interpreters::Base, nil]
      attr_accessor :next

      # @return [AST::Expression]
      attr_reader :node

      def initialize(node)
        @node = node

        return unless node.next

        @next = TreeConstructor.ast_node_to_interpreter(node.next)
      end

      # Interpret the input, return result or forward to next node.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      def interpret(_input, _root)
        raise NotImplementedError, 'subclass must implement #interpret'
      end
    end
  end
end
