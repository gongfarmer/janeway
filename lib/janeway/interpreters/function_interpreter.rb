# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets a jsonpath function call within a filter selector.
    class FunctionInterpreter < Base
      alias function node

      # Specify the parameter types that built-in JsonPath functions require
      # @return [Hash<Symbol, Array<Symbol>] function name => list of parameter types
      FUNCTION_PARAMETER_TYPES = {
        length: [:value_type],
        count: [:nodes_type],
        match: %i[value_type value_type],
        search: %i[value_type value_type],
        value: [:nodes_type],
      }.freeze

      # @param [AST::Function]
      def initialize(function)
        super
        @params = function.parameters.map { |param| TreeConstructor.ast_node_to_interpreter(param) }
      end

      # @param input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      def interpret(input, root)
        params = interpret_function_parameters(@params, input, root)
        function.body.call(*params)
      end

      # Evaluate the expressions in the parameter list to make the parameter values
      # to pass in to a JsonPath function.
      #
      # The node lists returned by a singular query must be deconstructed into a single value for
      # parameters of ValueType, this is done here.
      # For explanation:
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-well-typedness-of-function-
      #
      # @param parameters [Array] parameters before evaluation
      # @param func [String] function name (eg. "length", "count")
      # @param input [Object]
      # @return [Array] parameters after evaluation
      def interpret_function_parameters(parameters, input, root)
        param_types = FUNCTION_PARAMETER_TYPES[function.name.to_sym]

        parameters.map.with_index do |parameter, i|
          type = param_types[i]
          case parameter.node
          when AST::CurrentNode, AST::RootNode
            result = parameter.interpret(input, root)
            if type == :value_type && parameter.node.singular_query?
              deconstruct(result)
            else
              result
            end
          when AST::Function, AST::StringType then parameter.interpret(input, root)
          when String then parameter.value # from a TreeConstructor::Literal
          else
            # invalid parameter type. Function must accept it and return Nothing result
            parameter
          end
        end
      end

      # Prepare a value to be passed to as a parameter with type ValueType.
      # Singular queries (see RFC) produce a node list containing one value.
      # Return the value.
      #
      # Implements this part of the RFC:
      #   > When the declared type of the parameter is ValueType and
      #     the argument is one of the following:
      #   > ...
      #   >
      #   > A singular query. In this case:
      #   > * If the query results in a nodelist consisting of a single node,
      #       the argument is the value of the node.
      #   > * If the query results in an empty nodelist, the argument is
      #       the special result Nothing.
      #
      # @param input [Object] usually an array - sometimes a basic type like String, Numeric
      # @return [Object] basic type -- string or number
      def deconstruct(input)
        return input unless input.is_a?(Array)

        if input.size == 1
          # FIXME: what if it was a size 1 array that was intended to be a node not a node list? How to detect this?
          input.first
        elsif input.empty?
          NOTHING
        else
          input # input is a single node, which happens to be an Array
        end
      end
    end
  end
end
