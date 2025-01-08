# frozen_string_literal: true

require 'English'

# JsonPath2 jsonpath parsing library
module JsonPath2
  # JsonPath2 Abstract Syntax Tree
  module AST
  end

  # Apply a JsonPath query to the givein input, and return the result.
  #
  # @param input [Object] ruby object to be indexed
  # @param query [String] jsonpath query
  # @return [Object] result of applying query to input
  def self.on(input, query)
    query = compile(query)
    JsonPath2::Interpreter.new(input).interpret(query)
  end

  # Compile a JsonPath query into an Abstract Syntax Tree.
  # This can applied to inputs using the 'apply' method.
  #
  # Use this to compile the query once and then re-use it for
  # multiple inputs later.
  #
  # @param query [String] jsonpath query
  # @return [JsonPath2::AST::Query]
  def self.compile(query, logger = nil)
    logger ||= Logger.new(IO::NULL)
    tokens = JsonPath2::Lexer.lex(query)
    JsonPath2::Parser.new(tokens, logger).parse
  end

  # Apply JsonPath2::AST::Query to input and return the results.
  #
  # This does not accept a string query.
  # Use this to apply the result of JsonPath2.compile to various inputs.
  #
  # @param input [Object] ruby object to be indexed
  # @param ast [JsonPath2::AST::Query]
  def self.apply(input, ast)
    raise ArgumentError, "expect JsonPath2::AST::Query, got #{ast.inspect}" unless ast.is_a?(JsonPath2::AST::Query)

    JsonPath2::Interpreter.new(input).interpret(ast)
  end
end

# Require ruby source files in the given dir. Do not recurse to subdirs.
# @param dir [String] dir path relative to __dir__
# @return [void]
def require_libs(dir)
  absolute_path = File.join(__dir__, dir)
  raise "No such dir: #{dir.inspect}" unless File.directory?(absolute_path)

  Dir.children(absolute_path).sort.each do |filename|
    next if File.directory?(File.join(absolute_path, filename))

    rel_path = File.join(dir, filename)
    require_relative(rel_path[0..-4]) # omits ".rb" extension
  end
end

# These are dependencies of the other AST source files, and must come first
require_relative 'jsonpath2/ast/expression'

require_libs('jsonpath2/ast')
require_libs('jsonpath2')
