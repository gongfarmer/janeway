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
        # Apply filter expressions to the input data
        node_list = []
        input.each do |key, value|
          # Run filter and interpret result
          result = @expr.interpret(value, nil, root, [])
          case result
          when TrueClass then node_list << [key, value] # comparison test - pass
          when FalseClass then nil # comparison test - fail
          when Array then node_list << [key, value] unless result.empty? # existence test - node list
          else
            node_list << [key, value] # existence test. Null values here == success.
          end
        end
        return node_list.map(&:last) unless @next

        # Apply child selector to each node in the output node list
        results = []
        node_list.each do |key, value|
          results.concat @next.interpret(value, input, root, path + [key])
        end
        results
      end

      # Interpret selector on the input.
      # @param input [Array] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      def interpret_array(input, root, path)
        # Apply filter expressions to the input data
        node_list = []
        input.each_with_index do |value, i|
          # Run filter and interpret result
          result = @expr.interpret(value, nil, root, [])
          case result
          when TrueClass then node_list << [i, value] # comparison test - pass
          when FalseClass then nil # comparison test - fail
          when Array then node_list << [i, value] unless result.empty? # existence test - node list
          else
            node_list << [i, value] # existence test. Null values here == success.
          end
        end
        return node_list.map(&:last) unless @next

        # Apply child selector to each node in the output node list
        results = []
        node_list.each do |i, value|
          results.concat @next.interpret(value, input, root, path + [i])
        end
        results
      end

      # @return [Hash]
      def as_json
        { type: type, value: node.to_s, next: @next&.as_json }.compact
      end
    end
  end
end
