# frozen_string_literal: true

require_relative 'selector'

# https://datatracker.ietf.org/doc/rfc9535/

module Janeway
  module AST
    # Filter selectors are used to iterate over the elements or members of
    # structured values, i.e., JSON arrays and objects.  The structured
    # values are identified in the nodelist offered by the child or
    # descendant segment using the filter selector.

    # For each iteration (element/member), a logical expression (the
    # _filter expression_) is evaluated, which decides whether the node of
    # the element/member is selected.  (While a logical expression
    # evaluates to what mathematically is a Boolean value, this
    # specification uses the term _logical_ to maintain a distinction from
    # the Boolean values that JSON can represent.)

    # During the iteration process, the filter expression receives the node
    # of each array element or object member value of the structured value
    # being filtered; this element or member value is then known as the
    # _current node_.

    # The current node can be used as the start of one or more JSONPath
    # queries in subexpressions of the filter expression, notated via the
    # current-node-identifier @. Each JSONPath query can be used either for
    # testing existence of a result of the query, for obtaining a specific
    # JSON value resulting from that query that can then be used in a
    # comparison, or as a _function argument_.

    # Filter selectors may use function extensions, which are covered in
    # Section 2.4.  Within the logical expression for a filter selector,
    # function expressions can be used to operate on nodelists and values.
    # The set of available functions is extensible, with a number of
    # functions predefined (see Section 2.4) and the ability to register
    # further functions provided by the "Function Extensions" subregistry
    # (Section 3.2).  When a function is defined, it is given a unique
    # name, and its return value and each of its parameters are given a
    # _declared type_. The type system is limited in scope; its purpose is
    # to express restrictions that, without functions, are implicit in the
    # grammar of filter expressions.  The type system also guides
    # conversions (Section 2.4.2) that mimic the way different kinds of
    # expressions are handled in the grammar when function expressions are
    # not in use.
    #
    # @example: $.store[@.price < 10]
    class FilterSelector < Janeway::AST::Selector
      # @param brackets [Boolean] include brackets around selector
      # ** ignores keyword arguments that don't apply to this selector
      def to_s(brackets: true, **)
        brackets ? "[?#{value}]#{@next}" : "?#{value}#{@next}"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        if @next
          [indented(level, to_s), indented(level + 1, @next&.tree)]
        else
          [indented(level, to_s)]
        end
      end
    end
  end
end
