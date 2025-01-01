# frozen_string_literal: true

module JsonPath2
  module AST
    class BinaryOperator < JsonPath2::AST::Expression
      attr_accessor :operator, :left, :right

      def initialize(operator, left = nil, right = nil)
        super(nil)
        raise ArgumentError, "expect symbol, got #{operator.inspect}" unless operator.is_a?(Symbol)

        @operator = operator
        @left = left
        @right = right
      end

      def ==(other)
        operator == other&.operator && left == other.left && right == other.right
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
        when :union then ','
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
    end
  end
end
