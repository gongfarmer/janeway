# frozen_string_literal: true

module Janeway
  module AST
    # AST::Query holds the complete abstract syntax tree created by parsing the query.
    #
    # This can be frozen and passed to multiple threads or ractors for simultaneous use.
    # No instance members are modified during the interpretation stage.
    class Query
      # @return [AST::RootNode]
      attr_reader :root

      # The original jsonpath query, for use in error messages
      # @return [String]
      attr_reader :jsonpath

      # @param root_node [AST::Root]
      # @param jsonpath [String]
      def initialize(root_node, jsonpath)
        raise ArgumentError, "expect root identifier, got #{root_node.inspect}" unless root_node.is_a?(RootNode)
        raise ArgumentError, "expect query string, got #{jsonpath.inspect}" unless jsonpath.is_a?(String)

        @root = root_node
        @jsonpath = jsonpath
      end

      # Use this Query to search the input, and return the results.
      #
      # @param input [Object] ruby object to be searched
      # @return [Array] all matched objects
      def find_all(input)
        Janeway::Interpreter.new(self).interpret(input)
      end

      # Iterate through each value matched by the JSONPath query.
      #
      # @param input [Hash, Array] ruby object to be searched
      # @yieldparam [Object] matched value
      # @return [void]
      def each(input, &)
        return enum_for(:each, input) unless block_given?

        interpreter = Janeway::Interpreter.new(self)
        interpreter.push Janeway::Interpreters::Yielder.new(&)
        interpreter.interpret(input)
      end

      def to_s
        @root.to_s
      end

      # Return a list of all the nodes in the AST.
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

      # Remove the last selector in the query from the node list, and return the removed selector.
      # @return [AST::Selector, nil] last selector in the query, if any
      def pop
        nodes = node_list
        return nil if node_list.size == 1 # only 1 node, don't pop

        # Remove the last selector and return it
        last_node = nodes.pop
        nodes.last.next = nil # delete the second-last node's link to the last node
        last_node
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
end
