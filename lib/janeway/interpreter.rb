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

    # Interpret a query on the given input, return result
    # @param input [Hash, Array]
    # @param query [String]
    def self.interpret(input, query)
      tokens = Lexer.lex(query)
      ast = Parser.new(tokens, query).parse
      new(ast).interpret(input)
    end

    # @param query [AST::Query] abstract syntax tree of the jsonpath query
    def initialize(query)
      raise ArgumentError, "expect AST::Query, got #{query.inspect}" unless query.is_a?(AST::Query)

      @query = query
      @jsonpath = query.jsonpath
      @input = nil
      @pipeline = []
    end

    # @param input [Array, Hash] object to be searched
    # @return [Object]
    def interpret(input)
      @input = input
      unless @input.is_a?(Hash) || @input.is_a?(Array)
        return [] # can't query on any other types, but need to check because a string is also valid json
      end

      root_interpreter = query_to_interpreter_chain(@query)
      root_interpreter.interpret(nil, input)
    end

    private

    # @return [Interpreters::RootNodeInterpreter]
    def query_to_interpreter_chain(query)
      chain =
        query.node_list.map do |node|
          Interpreters::TreeConstructor.ast_node_to_interpreter(node)
        end
      chain.each_with_index do |node, i|
        node.next = chain[i + 1]
      end
      chain.first
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
