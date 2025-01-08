# frozen_string_literal: true

require_relative 'location'

module JsonPath2
  # Base class for JSONPath query errors
  class Error < StandardError
    # @param message [String] error message
    # @param query [String] entire query string
    # @param location [Location] location of error
    def initialize(message, query = nil, location = nil)
      super(message)
      @query = query
      @location = location
    end
  end
end
