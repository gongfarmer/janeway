# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # A wildcard selector selects the nodes of all children of an object
    # or array. The order in which the children of an object appear in
    # the resultant nodelist is not stipulated, since JSON objects are
    # unordered. Children of an array appear in array order in the
    # resultant nodelist.
    #
    # Note that the children of an object are its member values, not its member names.
    #
    # The wildcard selector selects nothing from a primitive JSON value (ie. a number, a string, true, false, or null).
    #
    # It has only one possible value: '*'
    # @example: $.store.book[*]
    class WildcardSelector < JsonPath2::AST::Selector
      def to_s
        '*'
      end
    end
  end
end
