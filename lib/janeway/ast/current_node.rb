# frozen_string_literal: true

module Janeway
  module AST
    # CurrentNode addresses the current node of the filter-selector that is directly enclosing the identifier.
    #
    # Note: Within nested filter-selectors, there is no syntax to address the
    # current node of any other than the directly enclosing filter-selector
    # (i.e., of filter-selectors enclosing the filter-selector that is directly
    # enclosing the identifier).
    #
    # It may be followed by another selector which is applied to it.
    # Within the IETF examples, I see @ followed by these selectors:
    #   * name selector (dot notation)
    #   * filter selector (bracketed)
    #   * wildcard selector
    # Probably best to assume that any selector type could appear here.
    #
    # It may also not be followed by any selector, and be used directly with a comparison operator.
    #
    # @example
    #   $.a[?@.b == 'kilo']
    #   $.a[?@.b]
    #   $[?@.*]
    #   $[?@[?@.b]]
    #   $.a[?@<2 || @.b == "k"]
    #   $.o[?@>1 && @<4]
    #   $.a[?@ == @]
    #
    # Construct accepts an optional Selector which will be applied to the "current" node
    class CurrentNode < Janeway::AST::Expression
      def to_s
        "@#{@value}"
      end

      # True if this is the root of a singular-query.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-well-typedness-of-function-
      #
      # @return [Boolean]
      def singular_query?
        return true unless @value # there are no following selectors

        selector_types = []
        selector = @value
        loop do
          selector_types << selector.class
          selector = selector.next
          break unless selector
        end
        allowed = [AST::IndexSelector, AST::NameSelector]
        selector_types.uniq.all? { allowed.include?(_1) }
      end

      # True if this is a bare current node operator, without a following expression
      # @return [Boolean]
      def empty?
        @value.nil?
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, '@'), @value.tree(indent + 1)]
      end
    end
  end
end
