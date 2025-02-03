# frozen_string_literal: true

require 'English'

# Janeway JSONPath query library
#
# https://github.com/gongfarmer/janeway
module Janeway
  # Parse a jsonpath string and combine it with data to make an Enumerator.
  #
  # The Enumerator can be used to apply the query to the data using Enumerator
  # module methods such as #each and #map.
  #
  # @param jsonpath [String] jsonpath query
  # @param data [Array, Hash] input data
  # @return [Janeway::Enumerator]
  def self.enum_for(jsonpath, data)
    query = compile(jsonpath)
    Janeway::Enumerator.new(query, data)
  end

  # Parse a JSONPath string into a Janeway::Query object.
  #
  # This object can be combined with data to create Enumerators that apply the query to the data.
  #
  # Use this method if you want to parse the query once and re-use it for multiple data sets.
  #
  # Otherwise, use Janeway.enum_for to parse the query and pair it with data in a single step.
  #
  # @example
  #     query = Janeway.compile('$.store.books[? length(@.title) > 20]')
  #     long_title_books = query.enum_for(data_source_one).search
  #     query.enum_for(data_source_two).each do |book|
  #       long_title_books << book
  #     end
  #
  # @param query [String] jsonpath query
  # @return [Janeway::AST::Query]
  def self.compile(query)
    Janeway::Parser.parse(query)
  end
end

require_relative 'janeway/enumerator'
require_relative 'janeway/error'
require_relative 'janeway/functions'
require_relative 'janeway/interpreter'
require_relative 'janeway/lexer'
require_relative 'janeway/location'
require_relative 'janeway/normalized_path'
require_relative 'janeway/parser'
require_relative 'janeway/query'
require_relative 'janeway/token'
require_relative 'janeway/version'
