# frozen_string_literal: true

module JsonPath2
  module AST
    class String < JsonPath2::AST::Expression
      def ==(other)
        value == other&.value
      end

      def children
        []
      end
    end
  end
end
