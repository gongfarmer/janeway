# frozen_string_literal: true

module JsonPath2
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
    class Root < JsonPath2::AST::Expression
      def ==(other)
        self.class == other.class
      end

      def to_s
        "$#{@value}"
      end
    end
  end
end
