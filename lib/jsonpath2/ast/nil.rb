# frozen_string_literal: true

module JsonPath2
  module AST
    class Nil < JsonPath2::AST::Expression
      def ==(other)
        self.class == other.class && value == other&.value
      end

      def children
        []
      end
    end
  end
end
