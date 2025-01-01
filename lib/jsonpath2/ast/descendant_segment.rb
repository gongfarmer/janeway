# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # An array slice start:end:step ({{slice}}) selects a series of elements from
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
    class DescendantSegment < JsonPath2::AST::Selector
      # @return [AST::Selector]
      def child
        value
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, '..'), child.tree(level + 1)]
      end
    end
  end
end
