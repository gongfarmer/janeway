# frozen_string_literal: true

module Janeway
  # Query holds the abstract syntax tree created by parsing the query.
  # This can be frozen and passed to multiple threads or ractors for simultaneous use.
  # No instance members are modified during the interpretation stage.
  class Query
    # The original jsonpath query, for use in error messages
    # @return [String]
    attr_reader :jsonpath

    # @return [AST::Root]
    attr_reader :root

    # @param root_node [AST::Root]
    # @param jsonpath [String]
    def initialize(root_node, jsonpath)
      raise ArgumentError, "expect root identifier, got #{root_node.inspect}" unless root_node.is_a?(AST::RootNode)
      raise ArgumentError, "expect query string, got #{jsonpath.inspect}" unless jsonpath.is_a?(String)

      @root = root_node
      @jsonpath = jsonpath
    end

    # Combine this query with input to make an Enumerator.
    # This can be used to iterate over results with #each, #map, etc.
    #
    # @return [Janeway::Enumerator]
    def enum_for(input)
      Janeway::Enumerator.new(self, input)
    end

    # @return [String]
    def to_s
      @root.to_s
    end

    # Return true if this query can only possibly match 0 or 1 elements in any input.
    # Such a query must be composed exclusively of the root identifier followed by
    # name selectors and / or index selectors.
    # @return [Boolean]
    def singular_query?
      @root.singular_query?
    end

    # Return a list of the nodes in the AST.
    # The AST of a jsonpath query is a straight line, so this is expressible as an array.
    # The only part of the AST with branches is inside a filter selector, but that doesn't show up here.
    # @return [Array<Expression>]
    def node_list
      nodes = []
      node = @root
      loop do
        nodes << node
        break unless node.next

        node = node.next
      end
      nodes
    end

    # Queries are considered equal if their ASTs evaluate to the same JSONPath string.
    #
    # The string output is generated from the AST and should be considered a "normalized"
    # form of the query. It may have different whitespace and parentheses than the original
    # input but will be semantically equivalent.
    def ==(other)
      to_s == other.to_s
    end

    # Print AST in tree format
    # Every AST class prints a 1-line representation of self, with children on separate lines
    def tree
      result = @root.tree(0)

      result.flatten.join("\n")
    end

    # Deep copy the query
    # @return [Query]
    def dup
      Parser.parse(to_s)
    end

    # Delete the last element from the chain of selectors.
    # For a singular query, this makes the query point to the match's parent instead of the match itself.
    #
    # Don't do this for a non-singular query, those may contain child segments and
    # descendant segments which would lead to different results.
    #
    # @return [AST::Selector]
    def pop
      unless singular_query?
        raise Janeway::Error.new('not allowed to pop from a non-singular query', to_s)
      end

      # Sever the link to the last selector
      nodes = node_list
      if nodes.size == 1
        # Special case: cannot pop from the query "$" even though it is a singular query
        raise Janeway::Error.new('cannot pop from single-element query', to_s)
      end

      nodes[-2].next = nil

      # Return the last selector
      nodes.last
    end
  end
end
