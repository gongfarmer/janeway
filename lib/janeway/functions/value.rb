# frozen_string_literal: true

module Janeway
  # Parses jsonpath function calls, and defines the code for jsonpath builtin functions
  module Functions
    #  2.4.8. value() Function Extension

    # Parameters:
    #   1. NodesType
    # Result:
    #   ValueType
    #
    # The value() function extension provides a way to convert an instance of
    # NodesType to a value and make that available for further processing in
    # the filter expression:
    #
    # @example $[?value(@..color) == "red"]
    #
    # Its only argument is an instance of NodesType (possibly taken from a
    # filter-query, as in the example above). The result is an instance of
    # ValueType.
    #
    # If the argument contains a single node, the result is the value of the node.
    #
    # If the argument is the empty nodelist or contains multiple nodes, the result is Nothing.
    #
    # Note: A singular query may be used anywhere where a ValueType is
    # expected, so there is no need to use the value() function extension with a singular query.
    def parse_function_value
      consume # function
      raise "expect group_start token, found #{current}" unless current.type == :group_start

      consume # (

      # Read parameter
      parameters = [parse_function_parameter]
      raise Error, 'Too many parameters for value() function call' unless current.type == :group_end

      AST::Function.new('value', parameters) do |nodes|
        if nodes.is_a?(Array) && nodes.size == 1
          nodes.first
        else
          :nothing
        end
      end
    end
  end
end
