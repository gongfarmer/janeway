# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # An index selector, e.g. 3, selects an indexed child of an array
    # @example: $.store.book[2].title
    class IndexSelector < JsonPath2::AST::Selector
      # These are the limits of what javascript's Number type can represent
      MIN = -9_007_199_254_740_991
      MAX = 9_007_199_254_740_991

      def initialize(index)
        raise Error, "Invalid value for index selector: #{index.inspect}" unless index.is_a?(Integer)
        raise Error, "Index selector value too small: #{index.inspect}" if index < MIN
        raise Error, "Index selector value too large: #{index.inspect}" if index > MAX

        super
      end

      def to_s(brackets: true)
        brackets ? "[#{@value}]" : @value.to_s
      end
    end
  end
end
