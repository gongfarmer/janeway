# frozen_string_literal: true

# number              = (int / "-0") [ frac ] [ exp ] ; decimal number
# frac                = "." 1*DIGIT                  ; decimal fraction
# exp                 = "e" [ "-" / "+" ] 1*DIGIT    ; decimal exponent
module JsonPath2
  module AST
    class Number < JsonPath2::AST::Expression
      def ==(other)
        value == other&.value
      end

      def children
        []
      end
    end
  end
end
