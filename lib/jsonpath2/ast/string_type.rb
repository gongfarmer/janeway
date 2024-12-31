# frozen_string_literal: true

module JsonPath2
  module AST
    class StringType < JsonPath2::AST::Expression
      def ==(other)
        value == other&.value
      end

      def to_s
        if @value.include?("'")
          %("#{@value}"')
        else
          "'#{@value}'"
        end
      end
    end
  end
end
