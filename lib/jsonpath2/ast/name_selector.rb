# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # A name selector, e.g. 'name', selects a named child of an object.
    # @example
    #   $.store
    #   $[store]
    # The dot or bracket part is not captured here, only the name
    class NameSelector < JsonPath2::AST::Selector
      alias name value
      attr_reader :children

      def initialize(value)
        super
        # FIXME: implement name matching requirements here
        raise "Invalid name: #{value.inspect}:#{value.class}" unless value.is_a?(String)

        @children = []
      end

      # Add a child expression which filters the results of this name selector
      def <<(expression)
        @children << expression
      end

      def to_s
        "#{@value}#{@children.map(&:to_s).join}"
      end
    end
  end
end
