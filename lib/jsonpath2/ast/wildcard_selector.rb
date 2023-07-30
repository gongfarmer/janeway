# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # A wildcard * ({{wildcard-selector}}) in the expression [*] selects all
    # children of a node and in the expression ..[*] selects all descendants of a node.
    #
    # It has only one possible value: '*'
    # @example: $.store.book[*]
    class WildcardSelector < JsonPath2::AST::Selector
    end
  end
end
