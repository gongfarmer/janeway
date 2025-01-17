# frozen_string_literal: true

require_relative 'location'

module Janeway
  # Base class for JSONPath query errors
  class Error < StandardError
    # @return [String]
    attr_reader :query

    # @return [Location, nil]
    attr_reader :location

    # @param message [String] error message
    # @param query [String] entire query string
    # @param location [Location] location of error
    def initialize(message, query = nil, location = nil)
      super("Jsonpath query #{query} - #{message}")
      @query = query
      @location = location
    end

    def detailed_message
      msg = "Error: #{message}\nQuery: #{query}\n"
      msg += (' ' * location.col) + '^' if @location
      msg
    end
  end
end
