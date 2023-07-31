# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # A name selector, e.g. 'name', selects a named child of an object.
    # @example: $.store["name"]
    class NameSelector < JsonPath2::AST::Selector
      attr_accessor :predicate

      def initialize(value)
        raise "Invalid name: #{value.inspect}:#{value.class}" unless value.is_a?(::String)

        super
      end

      def to_s
        "#<JsonPath2::AST::NameSelector:#{object_id} name=#{@value.inspect}>"
      end
    end
  end
end
