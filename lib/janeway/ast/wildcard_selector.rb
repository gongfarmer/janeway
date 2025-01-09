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
      attr_accessor :child

      def initialize
        super
        @child = nil
      end

      def to_s(brackets: true)
        if @child.is_a?(NameSelector) || @child.is_a?(WildcardSelector)
          if brackets
            "[*]#{@child.to_s(brackets: true)}"
          else
            "*.#{@child}"
          end
        else
          "*#{@child}"
        end
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, '*'), @child.tree(level + 1)]
      end
    end
  end
end
