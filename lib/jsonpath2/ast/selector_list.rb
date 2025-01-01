# frozen_string_literal: true

require 'forwardable'

# https://github.com/ietf-wg-jsonpath/draft-ietf-jsonpath-base/blob/main/draft-ietf-jsonpath-base.md#selectors
#
# A set of selectors within the same set of brackets, as a comma-separated list.
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
      extend Forwardable
      def_delegators :@value, :size, :first, :last

      # subsequent expression that modifies the result of this one
      attr_accessor :child

      def initialize
        # @value holds the expressions in this selector
        super([])
        @child = nil
      end

      # @return [Array]
      def children
        @value
      end

      # Add a selector to the list
      def <<(selector)
        raise ArgumentError, "expect Selector, got #{selector.inspect}" unless selector.is_a?(Selector)

        @value << selector
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
        format('[%s]%s', @value.map(&:to_s).join(', '), @child)
      end
    end
  end
end
