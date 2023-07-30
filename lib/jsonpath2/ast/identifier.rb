# frozen_string_literal: true

module JsonPath2
  module AST
    class Identifier < JsonPath2::AST::Expression
      attr_accessor :name

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

      def initialize(name)
        @name = name
      end

      def ==(other)
        name == other&.name
      end

      def children
        []
      end

      def expects?(next_token)
        EXPECTED_NEXT_TOKENS.include?(next_token)
      end
    end
  end
end
