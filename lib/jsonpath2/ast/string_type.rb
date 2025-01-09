# frozen_string_literal: true

module JsonPath2
  module AST
    class StringType < JsonPath2::AST::Expression
      def to_s
        if @value.include?("'")
          %("#{@value}"')
        else
          "'#{@value}'"
        end
      end

      # Return true if this is a literal expression
      # @return [Boolean]
      def literal?
        true
      end
    end
  end
end
