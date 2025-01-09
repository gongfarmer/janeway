# frozen_string_literal: true

module Janeway
  module AST
    class StringType < Janeway::AST::Expression
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
