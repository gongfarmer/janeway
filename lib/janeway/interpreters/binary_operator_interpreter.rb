# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets a binary operator within filter selector.
    class BinaryOperatorInterpreter < Base
      alias operator node

      # Set up the internal interpreter chain for the BinaryOperator.
      def initialize(operator)
        super
        @left = TreeConstructor.ast_node_to_interpreter(operator.left)
        @right = TreeConstructor.ast_node_to_interpreter(operator.right)
      end

      # The binary operators are all comparison operators that test equality.
      #
      #  * boolean values specified in the query
      #  * JSONPath expressions which must be evaluated
      #
      # After a JSONPath expression is evaluated, it results in a node list.
      # This may contain literal values or nodes, whose value must be extracted before comparison.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      def interpret(input, root)
        case operator.name
        when :and, :or
          # handle node list for existence check
          lhs = @left.interpret(input, root)
          rhs = @right.interpret(input, root)
        when :equal, :not_equal, :less_than, :greater_than, :less_than_or_equal, :greater_than_or_equal
          # handle node values for comparison check
          lhs = to_single_value @left.interpret(input, root)
          rhs = to_single_value @right.interpret(input, root)
        else
          raise "Don't know how to handle binary operator #{operator.name.inspect}"
        end
        send(:"interpret_#{operator.name}", lhs, rhs)
      end

      # Interpret a node and extract its value, in preparation for using the node
      # in a comparison operator.
      # Basic literals such as AST::Number and AST::StringType evaluate to a number or string,
      # but selectors and segments evaluate to a node list.  Extract the value (if any)
      # from the node list, or return basic type.

      # Convert an expression result into a single value suitable for use by a comparison operator.
      # Expression result may already ba single value (ie. from a literal like AST::String)
      # or it may be a node list from a singular query.
      #
      # Any node list is guaranteed not to contain multiple values because the expression that
      # produce it was already verified to be a singular query.
      #
      # @param node [AST::Expression]
      # @param input [Object]
      def to_single_value(result)
        # Return basic types (ie. from AST::Number, AST::StringType, AST::Null)
        return result unless result.is_a?(Array)

        # Node lists are returned by Selectors, ChildSegment, DescendantSegment.
        #
        # For a comparison operator, an empty node list represents a missing element.
        # This must not match any literal value (including null/nil) but must match another missing value.
        return NOTHING if result.empty?

        # The parsing stage has already verified that both the left and right
        # expressions evaluate to a single value. Both are either a literal or a singular query.
        # So, this check will never raise an error.
        raise 'node list contains multiple elements but this is a comparison' unless result.size == 1

        result.first # Return the only node in the node list
      end

      # @param lhs [String, Numeric, Symbol, nil] string/number/null or NOTHING
      # @param rhs [String, Numeric, Symbol, nil] string/number/null or NOTHING
      def interpret_equal(lhs, rhs)
        lhs == rhs
      end

      # Interpret != operator
      def interpret_not_equal(lhs, rhs)
        !interpret_equal(lhs, rhs)
      end

      # Interpret && operator
      # May receive node lists, in which case empty node list == false
      def interpret_and(lhs, rhs)
        # non-empty array is already truthy, so that works properly without conversion
        lhs = false if lhs == []
        rhs = false if rhs == []
        lhs && rhs
      end

      # Interpret || operator
      # May receive node lists, in which case empty node list == false
      def interpret_or(lhs, rhs)
        # non-empty array is already truthy, so that works properly without conversion
        lhs = false if lhs.is_a?(Array) && lhs.empty?
        rhs = false if rhs.is_a?(Array) && rhs.empty?
        lhs || rhs
      end

      def interpret_less_than(lhs, rhs)
        lhs < rhs
      rescue StandardError
        false
      end

      def interpret_less_than_or_equal(lhs, rhs)
        # Must be done in 2 comparisons, because the equality comparison is
        # valid for many types that do not support the < operator.
        return true if interpret_equal(lhs, rhs)

        lhs < rhs
      rescue StandardError
        # This catches type mismatches like {} <= 1
        # RFC says that both < and > return false for such comparisons
        false
      end

      def interpret_greater_than(lhs, rhs)
        lhs > rhs
      rescue StandardError
        false
      end

      def interpret_greater_than_or_equal(lhs, rhs)
        return true if interpret_equal(lhs, rhs)

        lhs > rhs
      rescue StandardError
        false
      end

      # @param boolean [AST::Boolean]
      # @return [Boolean]
      def interpret_boolean(boolean, _input)
        boolean.value
      end

      # @param number [AST::Number]
      # @return [Integer, Float]
      def interpret_number(number, _input)
        number.value
      end

      # @param string [AST::StringType]
      # @return [String]
      def interpret_string_type(string, _input)
        string.value
      end

      # @param _null [AST::Null] ignored
      # @param _input [Object] ignored
      def interpret_null(_null, _input)
        nil
      end
    end
  end
end
