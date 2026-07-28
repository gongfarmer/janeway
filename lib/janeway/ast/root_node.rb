# frozen_string_literal: true

module Janeway
  module AST
    # Every JSONPath query (except those inside filter expressions; see Section
    # 2.3.5) MUST begin with the root identifier $.
    #
    # The root identifier $ represents the root node of the query argument and produces
    # a nodelist consisting of that root node.
    #
    # The root identifier may also be used in the filter selectors.
    #
    # @example:
    #   $(? $.key1 == $.key2 )
    #
    class RootNode < Janeway::AST::Expression
      def to_s
        "$#{@next}"
      end

      # True if this is the root of a singular-query.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-well-typedness-of-function-
      #
      # @return [Boolean]
      def singular_query?
        chain_of?(AST::IndexSelector, AST::NameSelector)
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level = 0)
        [indented(level, '$'), @next&.tree(level + 1)]
      end
    end
  end
end
