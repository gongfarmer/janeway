# frozen_string_literal: true

module JsonPath2
  module AST
    # Represent unary operators "!", "-"
    class UnaryOperator < JsonPath2::AST::Expression
      attr_accessor :operator, :operand

      def initialize(operator, operand = nil)
        super()
        @operator = operator
        @operand = operand
      end

      def to_s
        "#{@operator} #{operand}"
      end

      def ==(other)
        operator == other&.operator && operand == other&.operand
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        indented(level, "#{operator}#{operand}")
      end
    end
  end
end
