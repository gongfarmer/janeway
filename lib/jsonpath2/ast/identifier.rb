# frozen_string_literal: true

module JsonPath2
  module AST
    class Identifier < JsonPath2::AST::Expression
      alias name value

      # TODO: This list is incomplete. Complete after some aspects of the parser become clearer.
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

      def ==(other)
        name == other&.name
      end

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
