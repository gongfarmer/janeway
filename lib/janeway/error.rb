# frozen_string_literal: true

require_relative 'location'

module Janeway
  # Error class for Janeway.
  # Contains a copy of the jsonpath query string.
  # Lexer errors may also include the index into the query string that
  # points at which token was being lexed at the time of the error.
  class Error < StandardError
    # @return [String]
    attr_reader :query

    # @return [Location, nil]
    attr_reader :location

    # @param message [String] error message
    # @param query [String] entire query string
    # @param location [Location] location of error
    def initialize(msg, query = nil, location = nil)
      super("Jsonpath query #{query} - #{msg}")
      @query = query
      @location = location
    end
  end
end
