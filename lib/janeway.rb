# frozen_string_literal: true

require 'English'

# Janeway jsonpath parsing library
module Janeway
  # Abstract Syntax Tree
  module AST
    # These are the limits of what javascript's Number type can represent
    INTEGER_MIN = -9_007_199_254_740_991
    INTEGER_MAX = 9_007_199_254_740_991
  end

  # Apply a JsonPath query to the input, and return the result.
  #
  # @param query [String] jsonpath query
  # @param input [Object] ruby object to be searched
  # @return [Array] all matched objects
  def self.find_all(query, input)
    query = compile(query)
    Janeway::Interpreter.new(input).interpret(query)
  end

  # Compile a JsonPath query into an Abstract Syntax Tree.
  #
  # This can be used and re-used later on multiple inputs.
  #
  # @param query [String] jsonpath query
  # @return [Janeway::AST::Query]
  def self.compile(query)
    Janeway::Parser.parse(query)
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
require_relative 'janeway/ast/expression'

require_libs('janeway/ast')
require_libs('janeway')
