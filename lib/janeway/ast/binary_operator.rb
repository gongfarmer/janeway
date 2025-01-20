# frozen_string_literal: true

module Janeway
  module AST
    class BinaryOperator < Janeway::AST::Expression
      attr_reader :name, :left, :right

      def initialize(operator, left = nil, right = nil)
        super(nil)
        raise ArgumentError, "expect symbol, got #{operator.inspect}" unless operator.is_a?(Symbol)

        @name = operator # eg. :equal
        self.left = left if left
        self.right = right if right
      end

      # Set the left-hand-side expression
      # @param expr [AST::Expression]
      def left=(expr)
        if comparison_operator? && !(expr.literal? || expr.singular_query?)
          raise Error, "Expression #{expr} does not produce a singular value for #{operator_to_s} comparison"
        elsif comparison_operator? && expr.is_a?(AST::Function) && !expr.literal?
          msg = "Function #{expr} returns a non-comparable value which is not usable for #{operator_to_s} comparison"
          raise Error, msg
        end

        # Compliance test suite requires error for this, but don't have go so far as to bar every literal
        if expr.is_a?(Boolean) && right.is_a?(Boolean)
          raise Error, "Literal \"#{expr}\" must be compared to an expression, not another literal (\"#{left}\")"
        end

        @left = expr
      end

      # Set the left-hand-side expression
      # @param expr [AST::Expression]
      def right=(expr)
        if comparison_operator? && !(expr.literal? || expr.singular_query?)
          raise Error, "Expression #{expr} does not produce a singular value for #{operator_to_s} comparison"
        end

        # Compliance test suite requires error for this, but don't have go so far as to bar every literal
        if expr.is_a?(Boolean) && left.is_a?(Boolean)
          raise Error, "Literal \"#{expr}\" must be compared to an expression, not another literal (\"#{left}\")"
        end

        @right = expr
      end

      def to_s
        # Make precedence explicit by adding parentheses
        "(#{@left} #{operator_to_s} #{@right})"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [
          indented(level, to_s),
          @left.tree(level + 1),
          @right.tree(level + 1),
        ]
      end

      # True if this operator is a comparison operator
      # @return [Boolean]
      def comparison_operator?
        operator_type == :comparison
      end

      # True if this operator is a logical operator
      # @return [Boolean]
      def logical_operator?
        operator_type == :logical
      end

      private

      def operator_to_s
        case name
        when :and then '&&'
        when :equal then '=='
        when :greater_than then '>'
        when :greater_than_or_equal then '>='
        when :less_than then '<'
        when :less_than_or_equal then '<='
        when :not_equal then '!='
        when :or then '||'
        else
          raise "unknown binary operator #{name}"
        end
      end

      def operator_type
        case name
        when :and, :or then :logical
        when :equal, :not_equal, :greater_than, :greater_than_or_equal, :less_than, :less_than_or_equal then :comparison
        else
          raise "unknown binary operator #{name}"
        end
      end
    end
  end
end
