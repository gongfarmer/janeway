# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # An index selector, e.g. 3, selects an indexed child of an array
    # @example: $.store.book[2].title
    class IndexSelector < JsonPath2::AST::Selector
      def initialize(index)
        raise "Invalid index: #{index.inspect}" unless index.is_a?(Integer)

        super
      end

      def to_s
        @value.to_s
      end
    end
  end
end
