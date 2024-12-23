# frozen_string_literal: true

require 'English'

# JsonPath2 jsonpath parsing library
module JsonPath2
  # JsonPath2 Abstract Syntax Tree
  module AST
  end

  # @param input [Object] ruby object to be indexed
  # @param query [String] jsonpath query
  # @return [Object] result of applying query to input
  def self.on(input, query, logger: nil)
    logger ||= Logger.new(IO::NULL)
    tokens = JsonPath2::Lexer.lex(query)
    ast = JsonPath2::Parser.new(tokens, logger).parse
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

$LOAD_PATH << __dir__

# These are dependencies of the other AST source files, and must come first
require_relative 'jsonpath2/ast/shared/expression_collection'
require_relative 'jsonpath2/ast/expression'

require_libs('jsonpath2/ast')
require_libs('jsonpath2/error/runtime')
require_libs('jsonpath2/error/syntax')
require_libs('jsonpath2')
