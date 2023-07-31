# frozen_string_literal: true

module JsonPath2
  module AST
    class Root < JsonPath2::AST::Expression
      def ==(other)
        children == other&.children
      end

      def children
        [expression]
      end
    end
  end
end
