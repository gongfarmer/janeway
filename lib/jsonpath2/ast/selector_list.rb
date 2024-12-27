# frozen_string_literal: true

# https://github.com/ietf-wg-jsonpath/draft-ietf-jsonpath-base/blob/main/draft-ietf-jsonpath-base.md#selectors
#
# A collection of selectors all specified within the same set of brackets, as a comma-separated list.
#
# If multiple selectors exist, then their results are to be combined (possibly introducing
# duplicate elements in the result.)
#
# @example
#    $[*, *]
#    $[1, 2, 3]
#    $[name1, [1:10]]
module JsonPath2
  module AST
    # Represent a selector, which is an expression that filters nodes from a list based on a predicate.
    class SelectorList < JsonPath2::AST::Expression
      def initialize
        super([])
      end

      # Add a selector to the list
      def <<(selector)
        raise ArgumentError, "expect Selector, got #{selector.inspect}" unless selector.is_a?(Selector)

        @value << selector
      end

      # List selectors
      def children
        @value
      end

      # @return [Integer]
      def size
        @value.size
      end

      # @return [Ast::Selector]
      def first
        @value.first
      end

      def ==(other)
        case other
        when Array then @value == other
        when SelectorList then children == other.children
        else
          false
        end
      end

      def to_s
        @value.map(&:to_s).join(',')
      end
    end
  end
end
