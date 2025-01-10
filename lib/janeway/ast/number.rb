# frozen_string_literal: true

module Janeway
  module AST
    # Represent a number.  From the ABNF grammar:
    # number              = (int / "-0") [ frac ] [ exp ] ; decimal number
    # frac                = "." 1*DIGIT                  ; decimal fraction
    # exp                 = "e" [ "-" / "+" ] 1*DIGIT    ; decimal exponent
    class Number < Janeway::AST::Expression
      def to_s
        @value.to_s
      end

      # Return true if this is a literal expression
      # @return [Boolean]
      def literal?
        true
      end
    end
  end
end
