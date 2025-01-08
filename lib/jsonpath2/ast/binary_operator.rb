# frozen_string_literal: true

module JsonPath2
  module AST
    class BinaryOperator < JsonPath2::AST::Expression
      attr_reader :operator, :left, :right

      def initialize(operator, left = nil, right = nil)
        super(nil)
        raise ArgumentError, "expect symbol, got #{operator.inspect}" unless operator.is_a?(Symbol)

        @operator = operator
        self.left = left if left
        self.right = right if right
      end

      def ==(other)
        operator == other&.operator && left == other.left && right == other.right
      end

      # Set the left-hand-side value
      # @param expr [AST::Expression]
      def left=(expr)
        if comparison_operator? && !(expr.literal? || expr.singular_query?)
          raise Error, "Expression #{expr} does not produce a singular value for #{operator_to_s} comparison"
        end

        @left = expr
      end

      # Set the left-hand-side value
      # @param expr [AST::Expression]
      def right=(expr)
        if comparison_operator? && !(expr.literal? || expr.singular_query?)
          raise Error, "Expression #{expr} does not produce a singular value for #{operator_to_s} comparison"
        end

        @right = expr
      end

      def to_s
        # Make precedence explicit by adding parentheses
        "(#{@left} #{operator_to_s} #{@right})"
      end

      private

      def operator_to_s
        case operator
        when :and then '&&'
        when :equal then '=='
        when :greater_than then '>'
        when :greater_than_or_equal then '>='
        when :less_than then '<'
        when :less_than_or_equal then '<='
        when :not_equal then '!='
        when :or then '||'
        else
          raise "unknown binary operator #{operator}"
        end
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

      # True if this operator is a comparison operator, not a logical operator.
      # @return [Boolean]
      def comparison_operator?
        case operator
        when :and, :or then false
        when :equal, :not_equal, :greater_than, :greater_than_or_equal, :less_than, :less_than_or_equal then true
        else
          raise "unknown binary operator #{operator}"
        end
      end
    end
  end
end
