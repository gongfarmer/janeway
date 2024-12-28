# frozen_string_literal: true

module JsonPath2
  module AST
    # Syntactically, a JSONPath query consists of a root identifier ($),
    # which stands for a nodelist that contains the root node of the
    # query argument, followed by a possibly empty sequence of segments.
    class Query
      include JsonPath2::AST::Shared::ExpressionCollection

      # Represent AST as basic ruby types, for comparison
      def tree
        children.map(&:tree)
      end

      def to_s
        expressions.map(&:to_s).join
      end

      def ==(other)
        to_s == other.to_s
      end
    end
  end
end
