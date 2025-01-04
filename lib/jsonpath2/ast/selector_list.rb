# frozen_string_literal: true

require 'forwardable'

# A set of selectors within brackets, as a comma-separated list.
# https://www.rfc-editor.org/rfc/rfc9535.html#child-segment
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
      def_delegators :@value, :size, :first, :last, :each, :map

      # Subsequent expression that modifies the result of this selector list.
      # This one is not in the selector list, it comes afterward.
      attr_accessor :child

      def initialize
        super([]) # @value holds the expressions in the selector
        @child = nil # @child is the next expression, which modifies the output of this one
      end

      # Add a selector to the list
      def <<(selector)
        raise ArgumentError, "expect Selector, got #{selector.inspect}" unless selector.is_a?(Selector)

        @value << selector
      end

      def ==(other)
        case other
        when Array then @value == other
        when SelectorList then @value == other.value
        else
          false
        end
      end

      def to_s
        format('[%s]%s', @value.map(&:to_s).join(', '), @child)
      rescue Encoding::CompatibilityError=> e
        "[#{@value}]#{@child}"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        msg = format('[%s]', @value.map(&:to_s).join(', '))
        [indented(level, msg), @child&.tree(level + 1)]
      end
    end
  end
end
