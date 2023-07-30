# frozen_string_literal: true

module JsonPath2
  module AST
    class Return < JsonPath2::AST::Expression
      attr_accessor :expression

      def initialize(expr)
        @expression = expr
      end

      def ==(other)
        children == other&.children
      end

      def children
        [expression]
      end
    end
  end
end
