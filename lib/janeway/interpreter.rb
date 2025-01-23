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
      @pipeline = query_to_interpreter_pipeline(@query)
    end

    # @param input [Array, Hash] object to be searched
    # @return [Object]
    def interpret(input)
      @input = input
      unless @input.is_a?(Hash) || @input.is_a?(Array)
        return [] # can't query on any other types, but need to check because a string is also valid json
      end

      @pipeline.first.interpret(nil, nil, input)
    rescue StandardError => e
      # Error during interpretation. Convert it to a Janeway::Error and include the query in the message
      error = err(e.message)
      error.set_backtrace e.backtrace
      raise error
    end

    # Append an interpreter onto the end of the pipeline
    # @param [Interpreters::Base]
    def push(node)
      @pipeline.last.next = node
    end

    private

    # @return [Interpreters::RootNodeInterpreter]
    def query_to_interpreter_pipeline(query)
      pipeline =
        query.node_list.map do |node|
          Interpreters::TreeConstructor.ast_node_to_interpreter(node)
        end
      pipeline.each_with_index do |node, i|
        node.next = pipeline[i + 1]
      end
      pipeline
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
