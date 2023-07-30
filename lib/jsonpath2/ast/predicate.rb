# frozen_string_literal: true

# https://github.com/ietf-wg-jsonpath/draft-ietf-jsonpath-base/blob/main/draft-ietf-jsonpath-base.md#selectors
# Selectors:
#
# A name selector, e.g. 'name', selects a named child of an object.
#
# An index selector, e.g. 3, selects an indexed child of an array.
#
# A wildcard * ({{wildcard-selector}}) in the expression [*] selects all
# children of a node and in the expression ..[*] selects all descendants of a
# node.
#
# An array slice start:end:step ({{slice}}) selects a series of elements from
# an array, giving a start position, an end position, and an optional step
# value that moves the position from the start to the end.
#
# Filter expressions ?<logical-expr> select certain children of an object or array, as in:
#
# $.store.book[?@.price < 10].title
module JsonPath2
  module AST
    # Represent the predicate of a selector.
    # Accept name, index, wildcard, slice or filter expressions
    class Predicate < JsonPath2::AST::Expression
      attr_accessor :predicate

      def ==(other)
        predicate == other&.predicate
      end

      def children
        [predicate]
      end
    end
  end
end
