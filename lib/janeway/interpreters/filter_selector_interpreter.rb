# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets a filter selector, returns results or forwards them to next selector
    class FilterSelectorInterpreter < Base
      alias selector node

      # Set up the internal interpreter chain for the FilterSelector.
      # @param selector [AST::FilterSelector]
      def initialize(selector)
        super
        @expr = self.class.setup_interpreter_tree(selector)
      end

      # FIXME: should this be combined with similar func in Interpreter?
      # FIXME: move this to a separate module?
      #
      # Set up a tree of interpreters which can process input for the filter expression.
      # For a jsonpath query like '$.a[?@.b == $.x]', this sets up interpreters for '@.b == $.x'.
      # @return [Interpreters::Base] root of the filter expression
      def self.setup_interpreter_tree(selector)
        TreeConstructor.ast_node_to_interpreter(selector.value)
      end

      # Interpret selector on the input.
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret(input, _parent, root, path)
        case input
        when Array then interpret_array(input, root, path)
        when Hash then interpret_hash(input, root, path)
        else [] # early exit
        end
      end

      # Interpret selector on the input.
      # @param input [Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_hash(input, root, path)
        node_list = []
        input.each { |key, value| node_list << [key, value] if filter_match?(value, root) }
        forward_matches(node_list, input, root, path)
      end

      # Interpret selector on the input.
      # @param input [Array] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_array(input, root, path)
        node_list = []
        input.each_with_index { |value, i| node_list << [i, value] if filter_match?(value, root) }
        forward_matches(node_list, input, root, path)
      end

      private

      # Classify the result of running the filter expression against a value.
      # Returns true if the value should be kept.
      def filter_match?(value, root)
        result = @expr.interpret(value, nil, root, [])
        case result
        when TrueClass then true    # comparison test - pass
        when FalseClass then false  # comparison test - fail
        when Array then !result.empty? # existence test - non-empty node list
        else true                   # existence test - null / other values count as success
        end
      end

      # Given a node_list of [key_or_index, value] pairs, apply @next to each
      # and concat the results. If no @next, return just the values.
      def forward_matches(node_list, input, root, path)
        return node_list.map(&:last) unless @next

        results = []
        node_list.each do |key, value|
          results.concat @next.interpret(value, input, root, path + [key])
        end
        results
      end

      public

      # @return [Hash]
      def as_json
        { type: type, value: node.to_s, next: @next&.as_json }.compact
      end
    end
  end
end
