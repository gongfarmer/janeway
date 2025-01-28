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
      # @param _input [Array, Hash] the results of processing so far
      # @param _root [Array, Hash] the entire input
      def interpret(_input, _root)
        raise NotImplementedError, 'subclass must implement #interpret'
      end

      # @return [String]
      def to_s
        @node.to_s
      end

      # Return hash representation of this selector interpreter
      # @return [Hash]
      def as_json
        if node
          { type: type, value: node&.value, next: @next&.as_json }.compact
        else
          { type: type, next: @next&.as_json }.compact
        end
      end

      # @return [AST::Selector] AST node containing this interpreter's data
      def selector
        nil # subclass should implement
      end

      def type
        self.class.to_s.split('::').last # eg. Janeway::AST::FunctionCall => "FunctionCall"
      end
    end
  end
end
