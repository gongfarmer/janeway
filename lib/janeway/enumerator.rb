# frozen_string_literal: true

module Janeway
  # Enumerator combines a parsed JSONpath query with input.
  # It provides enumerator methods.
  class Enumerator
    include Enumerable

    # @param query [Janeway::Query] @param input [Array, Hash]
    def initialize(query, input)
      @query = query
      @input = input

      raise ArgumentError, "expect Janeway::Query, got #{query.inspect}" unless query.is_a?(Query)
    end

    # Return a list of values from the input data that match the jsonpath query
    #
    # @return [Array] all matched objects
    def search
      Janeway::Interpreter.new(@query).interpret(@input)
    end

    # Iterate through each value matched by the JSONPath query.
    #
    # @yieldparam [Object] value matched by query
    # @yieldparam [Array, Hash] parent object that contains the value
    # @yieldparam [String, Integer] hash key or array index of the value within the parent object
    # @yieldparam [String] normalized jsonpath that uniqely points to this value
    # @return [void]
    def each(&block)
      return enum_for(:each) unless block_given?

      Janeway::Interpreter.new(@query, as: :iterator, &block).interpret(@input)
    end

    # Delete each value matched by the JSONPath query.
    # @return [Array, Hash]
    def delete
      Janeway::Interpreter.new(@query, as: :deleter).interpret(@input)
    end
  end
end
