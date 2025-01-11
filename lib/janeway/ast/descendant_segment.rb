# frozen_string_literal: true

require_relative 'selector'

module Janeway
  module AST
    # An array slice start:end:step selects a series of elements from
    # an array, giving a start position, an end position, and an optional step
    # value that moves the position from the start to the end.
    #
    # @example
    #   $..j      Values of keys equal to 'j'
    #   $..[0]    First entry of any array
    #   $..[*]    All values
    #   $..*      All values
    #   $..[*, *] All values, twice non-deterministic order
    #   $..[0, 1] Multiple segments
    class DescendantSegment < Janeway::AST::Selector
      # Subsequent expression that modifies the result of this selector list.
      attr_accessor :next

      def to_s
        "..#{@value}#{@next}"
      end

      # @return [AST::Selector]
      #
      def selector
        value
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, "..#{@value}"), child&.tree(level + 1)]
      end
    end
  end
end
