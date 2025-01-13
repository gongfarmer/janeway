# frozen_string_literal: true

require_relative 'selector'

module Janeway
  module AST
    # A wildcard selector selects the nodes of all children of an object
    # or array. The order in which the children of an object appear in
    # the resultant nodelist is not stipulated, since JSON objects are
    # unordered. Children of an array appear in array order in the
    # resultant nodelist.
    #
    # Note that the children of an object are its member values, not its member names/keys.
    #
    # The wildcard selector selects nothing from a primitive JSON value (ie. a number, a string, true, false, or null).
    #
    # It has only one possible value: '*'
    # @example: $.store.book[*]
    class WildcardSelector < Janeway::AST::Selector
      def initialize
        super
        @next = nil
      end

      def to_s(brackets: false, dot_prefix: true)
        if brackets
          "[*]#{@next&.to_s(brackets: true)}"
        elsif dot_prefix
          ".*#{@next}"
        else
          "*#{@next}"
        end
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, '*'), @next.tree(level + 1)]
      end
    end
  end
end
