# frozen_string_literal: true

require 'forwardable'

module Janeway
  module AST
    # Represent a union of 2 or more selectors.
    #
    # A set of selectors within brackets, as a comma-separated list.
    # https://www.rfc-editor.org/rfc/rfc9535.html#child-segment
    #
    # @example
    #    $[*, *]
    #    $[1, 2, 3]
    #    $[name1, [1:10]]
    class ChildSegment < Janeway::AST::Expression
      extend Forwardable

      def_delegators :@value, :size, :first, :last, :each, :map, :empty?

      # Subsequent expression that modifies the result of this selector list.
      attr_accessor :next

      def initialize
        super([]) # @value holds the expressions in the selector
      end

      # Add a selector to the list
      def <<(selector)
        raise ArgumentError, "expect Selector, got #{selector.inspect}" unless selector.is_a?(Selector)

        @value << selector
      end

      def to_s(with_child: true)
        str = @value.map { |selector| selector.to_s(brackets: false, dot_prefix: false) }.join(', ')
        with_child ? "[#{str}]#{@next}" : "[#{str}]"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        msg = format('[%s]', @value.map(&:to_s).join(', '))
        [indented(level, msg), @next&.tree(level + 1)]
      end
    end
  end
end
