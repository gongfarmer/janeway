# frozen_string_literal: true

module JsonPath2
  module AST
    class Root < JsonPath2::AST::Expression
      def ==(other)
        self.class == other.class
      end
    end
  end
end
