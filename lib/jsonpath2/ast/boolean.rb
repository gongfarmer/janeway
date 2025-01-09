# frozen_string_literal: true

module JsonPath2
  module AST
    # Represent keywords true, false
    class Boolean < JsonPath2::AST::Expression
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
