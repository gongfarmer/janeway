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
    def on(input)
      Janeway::Enumerator.new(self, input)
    end

    def to_s
      @root.to_s
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
  end
end
