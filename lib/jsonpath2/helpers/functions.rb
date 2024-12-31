# frozen_string_literal: true

require_relative '../ast/function'

module JsonPath2
  module Helpers
    # Mixin to provide JSONPath function handlers for Parser
    module Functions
      # The length() function extension provides a way to compute the length of a value
      # and make that available for further processing in the filter expression:
      #
      # JSONPath return type: ValueType
      def parse_function_length
        consume # function
        log "current=#{current}, next_token=#{next_token}"

        # Read parameters
        parameters = []
        raise "expect group_start token, found #{current}" unless current.type == :group_start
        consume # (
        if current.type == :current_node
          parameters << parse_current_node
          consume
        else
          raise "don't know how to evaluate parameter #{current}"
        end
        raise "expect group_end token, found #{current}" unless current.type == :group_end
        #consume # )

        # If argument value is a string, result is the number of Unicode scalar values in the string.
        # If argument value is an array, result is the number of elements in the array.
        # If argument value is an object, result is the number of members in the object.
        # For any other argument value, the result is the special result Nothing.
        AST::Function.new('length', parameters) do |value|
          return value.size if [Array, Hash, String].include?(value.class)

          :nothing
        end
      end

      # The count() function extension provides a way to obtain the number of
      # nodes in a nodelist and make that available for further processing in
      # the filter expression:
      #
      # Its only argument is a nodelist. The result is a value (an unsigned
      # integer) that gives the number of nodes in the nodelist.
      #
      # Notes:
      #   * There is no deduplication of the nodelist.
      #   * The number of nodes in the nodelist is counted independent of
      #     their values or any children they may have, e.g., the count of a
      #     non-empty singular nodelist such as count(@) is always 1.
      #
      # @example $[?count(@.*.author) >= 5]
      def parse_function_count
        log "current=#{current}, next_token=#{next_token}"
        consume # function

        # Read parameters
        parameters = []
        raise "expect group_start token, found #{current}" unless current.type == :group_start
        consume # (
        if current.type == :current_node
          parameters << parse_current_node
          consume
        else
          raise "don't know how to evaluate parameter #{current}"
        end
        raise "expect group_end token, found #{current}" unless current.type == :group_end

        AST::Function.new('count', parameters) do |node_list|
          # probably need to allow Hash here too
          raise ArgumentError, "expect list, got #{node_list.inspect}" unless node_list.is_a?(Array)

          node_list.size
        end
      end
      def parse_function_match
      end
      def parse_function_search
      end
      def parse_function_value
      end
    end
  end
end
