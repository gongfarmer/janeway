# frozen_string_literal: true

module JsonPath2
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
    # @examples
    #   $.a[?@.b == 'kilo']
    #   $.a[?@.b]
    #   $[?@.*]
    #   $[?@[?@.b]]
    #   $.a[?@<2 || @.b == "k"]
    #   $.o[?@>1 && @<4]
    #   $.a[?@ == @]
    #
    # Construct accepts an optional Selector which will be applied to the "current" node
    class CurrentNode < JsonPath2::AST::Expression
      def to_s
        if @value.is_a?(NameSelector) || @value.is_a?(WildcardSelector)
          "@.#{@value}"
        else
          "@#{@value}"
        end
      end
    end
  end
end
