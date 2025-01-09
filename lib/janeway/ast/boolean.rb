# frozen_string_literal: true

module Janeway
  module AST
    # Represent keywords true, false
    class Boolean < Janeway::AST::Expression
      def to_s
        @value ? 'true' : 'false'
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end

      # Return true if this is a literal expression
      # @return [Boolean]
      def literal?
        true
      end
    end
  end
end
