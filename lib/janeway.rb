# frozen_string_literal: true

require 'English'

# Janeway JSONPath parsing library
module Janeway
  # Abstract Syntax Tree
  module AST
    # These are the limits of what javascript's Number type can represent
    INTEGER_MIN = -9_007_199_254_740_991
    INTEGER_MAX = 9_007_199_254_740_991
  end

  # Apply a JSONPath query to the input, and return all matched values.
  #
  # @param query [String] JSONPath query
  # @param input [Hash, Array] ruby object to be searched
  # @return [Array] all matched objects
  def self.find_all(query, input)
    ast = compile(query)
    Janeway::Interpreter.new(ast).interpret(input)
  end

  # Compile a JSONPath query into an Abstract Syntax Tree.
  #
  # This can be used and re-used later on multiple inputs.
  #
  # @param query [String] jsonpath query
  # @return [Janeway::AST::Query]
  def self.compile(query)
    Janeway::Parser.parse(query)
  end

  # Iterate through each value matched by the JSONPath query.
  #
  # @param query [String] jsonpath query
  # @param input [Hash, Array] ruby object to be searched
  # @yieldparam [Object] value matched by query
  # @yieldparam [Array, Hash] parent object that contains the value
  # @yieldparam [String, Integer] hash key or array index of the value within the parent object
  # @yieldparam [String] normalized jsonpath that uniqely points to this value
  # @return [void]
  def self.each(query, input, &block)
    raise ArgumentError, "Invalid jsonpath query: #{query.inspect}" unless query.is_a?(String)
    unless [Hash, Array, String].include?(input.class)
      raise ArgumentError, "Invalid input, expecting array or hash: #{input.inspect}"
    end

    Janeway::Parser.parse(query).each(input, &block)
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

require_libs('janeway/ast')
require_libs('janeway')
