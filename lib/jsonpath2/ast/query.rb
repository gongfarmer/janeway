# frozen_string_literal: true

module JsonPath2
  module AST
    # Syntactically, a JSONPath query consists of a root identifier ($),
    # which stands for a nodelist that contains the root node of the
    # query argument, followed by a possibly empty sequence of segments.
    class Query
      attr_accessor :root

      def to_s
        @root.to_s
      end

      # Queries are considered equal if their ASTs evaluate to the same JSONPath string.
      #
      # This is only used by unit tests.
      # The string output is generated by the AST and should be considered a "normalized"
      # form of the query. It may have different whitespace and parentheses than the original input but
      # will be semantically equal.
      #
      # For parser unit tests, this is compact to read and is sufficient for finding parser bugs.
      def ==(other)
        to_s == other.to_s
      end

      # Print AST in tree format
      # Every AST class prints a 1-line representation of self, with children on separate lines
      def tree
        result = @root.tree(0)

        result.flatten.join("\n")
      end
    end
  end
end
