# frozen_string_literal: true

require_relative 'parser'
require_relative 'interpreters/tree_constructor'
Dir.children("#{__dir__}/interpreters").each { |path| require_relative "interpreters/#{path}" }

module Janeway
  # Tree-walk interpreter to apply the operations from the abstract syntax tree to the input.
  #
  # This is not intended to be thread-safe, so create this inside a thread as needed.
  # It should be created for a single query and then discarded.
  class Interpreter
    attr_reader :jsonpath, :output
    include Interpreters

    # Interpret a query on the given input, return result
    # @param input [Hash, Array]
    # @param query [String]
    def self.interpret(input, query)
      tokens = Lexer.lex(query)
      ast = Parser.new(tokens, query).parse
      new(ast).interpret(input)
    end

    # @param query [Query] abstract syntax tree of the jsonpath query
    def initialize(query, as: :finder, &block)
      raise ArgumentError, "expect Query, got #{query.inspect}" unless query.is_a?(Query)
      unless %i[finder iterator deleter].include?(as)
        raise ArgumentError, "invalid interpreter type: #{as.inspect}"
      end

      @query = query
      @type = as
      @jsonpath = query.jsonpath
      @root = query_to_interpreter_tree(@query, &block)
    end

    # Return multiline JSON string describing the interpreter tree.
    #
    # This is not used for parsing / interpretation.
    # It is intended to represent the interpreter tree to help with debugging.
    # This format makes the tree structure much clearer than the #inspect output does.
    #
    # @return [String]
    def to_json(options = {})
      JSON.pretty_generate(@root.as_json, *options)
    end

    # @param input [Array, Hash] object to be searched
    # @return [Object]
    def interpret(input)
      unless input.is_a?(Hash) || input.is_a?(Array)
        return [] # can't query on any other types, but need to check because a string is also valid json
      end

      @root.interpret(nil, nil, input, [])
    rescue StandardError => e
      # Error during interpretation. Convert it to a Janeway::Error and include the query in the message
      error = err(e.message)
      error.set_backtrace e.backtrace
      raise error
    end

    private

    # Build a tree of interpreter classes based on the query's abstract syntax tree.
    #
    # Child segments require special handling.
    # See the detailed explanation at the end of this file.
    #
    # @return [Interpreters::RootNodeInterpreter]
    def query_to_interpreter_tree(query, &block)
      # Build an interpreter for each selector
      interpreters =
        query.node_list.map do |node|
          Interpreters::TreeConstructor.ast_node_to_interpreter(node)
        end

      # Append iterotor / deleter as needed, to support #each, #delete operations
      case @type
      when :iterator then interpreters.push(Yielder.new(&block))
      when :deleter then interpreters.push make_deleter(interpreters.pop)
      end

      # Link interpreters together
      interpreters.each_with_index do |node, i|
        node.next = interpreters[i + 1]
      end

      # Child segments which contain multiple selectors are branches in the interpreter tree.
      #
      # For every child segment, remove all following interpreters and push
      # them "inside" the child segment interpreter.
      #
      # Work backwards in case there are multiple child segments.
      # For full explanation see the explanation at the end of this file.
      selectors = []
      interpreters.reverse_each do |node|
        if node.is_a?(Interpreters::ChildSegmentInterpreter)
          node.next = nil
          node.push(selectors.pop) until selectors.empty?
          selectors = [node]
        else
          selectors << node
        end
      end

      selectors.last
    end

    # Make a Deleter that will delete the results matched by a Selector.
    # @param interpreter [Interpreters::Base] interpeter subclass
    def make_deleter(interpreter)
      TreeConstructor.ast_node_to_deleter(interpreter.node)
    end

    # Return an Interpreter::Error with the specified message, include the query.
    #
    # @param msg [String] error message
    # @return [Parser::Error]
    def err(msg)
      Janeway::Error.new(msg, @jsonpath)
    end
  end
end
__END__
= Child Segment Handling

== Interpreter Tree Layout

The interpreter tree is mostly a straight line except for the case of child segments
(brackets) that contain multiple selectors, eg. "$.store['bicycle', 'book']".

Such child segments are branches in the tree.

In Janeway, child segments that contain only one selector are not represented
in the AST, only the selector itself is an AST node.
For the remainder of this explanation, the term 'child segment' refers to child
segments that contain multiple selectors.

== Child segment evaluation -- original approach and problem

The obvious approach to interpreting a child segment is to send the input to
each of the selectors, combine the resulting values, and forward that to then
'next' selector which follows the child segment.
This is how I originally implemented the Janeway interpeter.

That approach works fine when only values are being collected.
However Janeway now supports iteration with #each, so each interpretation 
step carries along some new context information:  the parent (object which
contains the current input value) and the path (list of array indices or hash
keys which define the path to the current input).

Interpreting a child segment by interpeting its selectors separately and combining the results
discards all of that context.  Fully interpreting selectors only returns
values, not the parent or path data.

== Child segment evaluation -- new approach

Instead, embrace the idea of the child segment being a branch in the tree.

Take the chain of selectors which comes after the child segment, and copy that chain
onto the selectors inside the child segment.

Consider this jsonpath:
    $.store['book', 'bicycle'].price

In the first approach, the interpretation tree has a diamond:

             bicycle
    $ store <          > price
              book

In the new approach, the interpretation tree splits into two separate branches

              bicycle - price
    $ store <
              book - price

This way, the parent and path information is passed down normally to the following selectors.

When a Yielder is pushed onto the interpreter tree, copies of it must be pushed onto
the end of every branch.
