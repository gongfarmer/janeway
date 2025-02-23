# frozen_string_literal: true

require 'English'
require_relative 'janeway/enumerator'
require_relative 'janeway/parser'

# Janeway JSONPath query library
#
# https://github.com/gongfarmer/janeway
module Janeway
  # Parse a jsonpath string and combine it with data to make an Enumerator.
  #
  # The Enumerator can be used to apply the query to the data using Enumerator
  # module methods such as #each and #map.
  #
  # @example Apply query to data and search to get array of results
  #   results = Janeway.parse('$.store.books[? length(@.title) > 20]').search
  #
  # @example Apply query to data and iterate over results
  #   enum = Janeway.parse('$.store.books[? length(@.title) > 20]')
  #   enum.each do |book|
  #     results << book
  #   end
  #
  # @see Janeway::Enumerator docs for more ways to use the Enumerator
  #
  # @param jsonpath [String] jsonpath query
  # @param data [Array, Hash] input data
  # @return [Janeway::Enumerator]
  def self.enum_for(jsonpath, data)
    query = parse(jsonpath)
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
  # @example Use a query to search several JSON files
  #   results = []
  #   query = Janeway.parse('$.store.books[? length(@.title) > 20]')
  #   data_files.each do |path|
  #     data = JSON.parse File.read(path)
  #     results.concat query.enum_for(data).search
  #   end
  #
  # @param query [String] jsonpath query
  # @return [Janeway::AST::Query]
  def self.parse(query)
    Janeway::Parser.parse(query)
  end

  # Transform a jsonpath singular query into an array of hash keys and/or array
  # indexes suitable for providing to Hash#dig or Array#dig.
  #
  # Only singular queries are allowed, meaning queries that contain only name
  # selectors (ie. hash keys) and index selectors (array indexes.)
  # The paths that are yielded to Enumerator#each are all suitable for this.
  #
  # @example convert normalized jsonpath to array of hash keys / array indices
  #   Janeway.path_to_diggable('$["a"].b.c[0]') => ["a", "b", "c", 0]
  #
  # @param jsonpath [String] jsonpath query
  # @return [Array<String, Integer>]
  def self.path_to_diggable(jsonpath)
    raise Janeway::Error.new('Query has nothing to dig', jsonpath) if jsonpath == '$'

    # Parse query and determine whether it can be converted
    query = parse(jsonpath)
    unless query.singular_query?
      raise Janeway::Error.new('Only a singular query can be converted to dig parameters', jsonpath)
    end

    # Convert query to a list of name and index selectors
    nodes = query.node_list
    nodes.shift # discard the root identifier

    # Extract values from selectors
    nodes.map(&:value)
  end
end
