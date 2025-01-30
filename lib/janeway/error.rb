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
      super("Jsonpath query #{query} - #{msg}")
      @query = query
      @location = location
    end
  end
end
