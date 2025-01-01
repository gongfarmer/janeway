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

      def ==(other)
        operator == other&.operator && operand == other&.operand
      end
    end
  end
end
