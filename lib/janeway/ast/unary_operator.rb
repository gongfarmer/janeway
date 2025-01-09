# frozen_string_literal: true

module Janeway
  module AST
    # Represent unary operators "!", "-"
    class UnaryOperator < Janeway::AST::Expression
      attr_accessor :operator, :operand

      def initialize(operator, operand = nil)
        super()
        @operator = operator
        @operand = operand
      end

      def to_s
        "#{@operator} #{operand}"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        indented(level, "#{operator}#{operand}")
      end
    end
  end
end
