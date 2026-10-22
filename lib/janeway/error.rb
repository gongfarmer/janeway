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
      prefix = 'Jsonpath query '
      pointer = query && location
      # The pointer is only right if the header's copy of the query is on one line
      shown = pointer ? query.tr("\r\n", '  ') : query
      full = +''
      full << "#{prefix}#{shown}" if query
      full << " (col #{location.col})" if location
      full << ' - ' unless full.empty?
      full << msg
      full << pointer_line(shown, location, prefix.length) if pointer
      super(full)
      @query = query
      @location = location
    end

    private

    # Build the line of carets that marks the problem, aligned under the query in the message header.
    # @param line [String] the query as shown in the header, on one line
    # @param location [Location]
    # @param offset [Integer] width of the text that comes before the query in the header
    # @return [String] starts with a newline
    def pointer_line(line, location, offset)
      col = (location.col || 0).clamp(0, line.length)
      length = (location.length || 1).clamp(1, [line.length - col, 1].max)
      "\n#{' ' * (offset + col)}#{'^' * length}"
    end
  end
end
