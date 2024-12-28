# frozen_string_literal: true

module JsonPath2
  module AST
    class Boolean < JsonPath2::AST::Expression
      def ==(other)
        case other
        when Boolean then value == other&.value
        when true, false then value == other
        else
          raise "don't know how to compare AST::Boolean to #{other.inspect}"
        end
      end

      def children
        []
      end

      def to_s
        @value ? 'true' : 'false'
      end
    end
  end
end
