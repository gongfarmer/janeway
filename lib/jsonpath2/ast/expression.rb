# frozen_string_literal: true

module JsonPath2
  module AST
    class Expression
      attr_accessor :value

      def initialize(val = nil)
        @value = val
      end

      # TODO: Both implementations below are temporary. Expression SHOULD NOT have a concrete implementation of these methods.
      def ==(other)
        self.class == other.class
      end

      def children
        []
      end

      def type
        self.class.to_s.split('::').last.underscore # e.g., JsonPath2::AST::FunctionCall becomes "function_call"
      end
    end
  end
end
