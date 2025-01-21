# frozen_string_literal: true

module Janeway
  module AST
    # Represents JSON null literal within a filter expression
    class Null < Janeway::AST::Expression
      def to_s
        'null'
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level = 0)
        indented(level, 'null')
      end

      # Return true if this is a literal expression
      # @return [Boolean]
      def literal?
        true
      end
    end
  end
end
