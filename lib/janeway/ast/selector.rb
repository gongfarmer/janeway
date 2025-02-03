# frozen_string_literal: true

require_relative 'expression'

module Janeway
  module AST
    # Represent a selector, which is an expression that filters nodes from a list based on a predicate.
    #
    # https://www.rfc-editor.org/rfc/rfc9535.html#name-selectors
    # Selectors:
    #
    # A name selector, e.g. 'name', selects a named child of an object.
    #
    # An index selector, e.g. 3, selects an indexed child of an array.
    #
    # A wildcard * in the expression [*] selects all children of a node and in
    # the expression ..[*] selects all descendants of a node.
    #
    # An array slice start:end:step selects a series of elements from an array,
    # giving a start position, an end position, and an optional step value that
    # moves the position from the start to the end.
    #
    # Filter expressions ?<logical-expr> select certain children of an object or array, as in:
    #     $.store.book[?@.price < 10].title
    class Selector < Janeway::AST::Expression
      # Subsequent expression that modifies the result of this selector list.
      attr_accessor :next

      def ==(other)
        value == other&.value
      end
    end
  end
end
