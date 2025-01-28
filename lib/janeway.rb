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

  # Pair a jsonpath query with data to make an enumerator.
  # This can be used to iterate over results with #each, #map an other standard
  # ruby methods.
  #
  # @param jsonpath [String] jsonpath query
  # @param data [Array, Hash] input data
  # @return [Janeway::Enumerator]
  def self.on(jsonpath, data)
    query = compile(jsonpath)
    Janeway::Enumerator.new(query, data)
  end

  # Compile a JSONPath query into an Abstract Syntax Tree.
  #
  # This can be combined with inputs (using #on) to create Enumerators.
  # @example
  #     query = Janeway.compile('$.store.books[? length(@.title) > 20]')
  #     long_title_books = query.on(local_json).search
  #     query.on(remote_json).each do |book|
  #       long_title_books << book
  #     end
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

require_libs('janeway/ast')
require_libs('janeway')
