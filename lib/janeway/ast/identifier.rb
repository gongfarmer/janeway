# frozen_string_literal: true

module Janeway
  module AST
    class Identifier < Janeway::AST::Expression
      alias name value

      # Tokens which may follow an identifier string
      EXPECTED_NEXT_TOKENS = %I[
        \n
        +
        -
        *
        /
        ==
        !=
        >
        <
        >=
        <=
        &&
        ||
      ].freeze

      # @return [String]
      def to_s
        @value
      end

      def expects?(next_token)
        EXPECTED_NEXT_TOKENS.include?(next_token)
      end
    end
  end
end
