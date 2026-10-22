# frozen_string_literal: true

require_relative 'location'

module Janeway
  # Error class for Janeway.
  # Contains a copy of the jsonpath query string.
  # Lexer errors may also include the index into the query string that
  # points at which token was being lexed at the time of the error.
  class Error < StandardError
    # JSONPath query
    # @return [String]
    attr_reader :query

    # For lexer errors, this is the index on the query string where the error was encountered
    # @return [Location, nil]
    attr_reader :location

    # @param msg [String] error message
    # @param query [String] entire query string
    # @param location [Location] location of error
    def initialize(msg, query = nil, location = nil)
      full = +''
      full << "Jsonpath query #{query}" if query
      full << " (col #{location.col})" if location
      full << ' - ' unless full.empty?
      full << msg
      full << pointer_line(query, location) if query && location
      super(full)
      @query = query
      @location = location
    end

    private

    # Build two lines that show the query and mark the problem with carets under it.
    # Newlines in the query are replaced with spaces so that the carets stay under the right column.
    # @param query [String]
    # @param location [Location]
    # @return [String] starts with a newline
    def pointer_line(query, location)
      line = query.tr("\r\n", '  ')
      col = (location.col || 0).clamp(0, line.length)
      length = (location.length || 1).clamp(1, [line.length - col, 1].max)
      "\n#{line}\n#{' ' * col}#{'^' * length}"
    end
  end
end
