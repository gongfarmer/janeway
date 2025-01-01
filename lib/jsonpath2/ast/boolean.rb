# frozen_string_literal: true

module JsonPath2
  module AST
    # Represent keywords true, false
    class Boolean < JsonPath2::AST::Expression
      def ==(other)
        case other
        when Boolean then value == other&.value
        when true, false then value == other
        else
          raise "don't know how to compare AST::Boolean to #{other.inspect}"
        end
      end

      def to_s
        @value ? 'true' : 'false'
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end
    end
  end
end
