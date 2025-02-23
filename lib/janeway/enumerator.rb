# frozen_string_literal: true

require_relative 'interpreter'

module Janeway
  # Enumerator combines a JSONPath query with input.
  # It provides methods for running queries on the input and enumerating over the results.
  class Enumerator
    include Enumerable

    # @return [Janeway::Query]
    attr_reader :query

    # @param query [Janeway::Query]
    # @param input [Array, Hash]
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

    # Delete values from the input that are matched by the JSONPath query.
    # @return [Array] deleted values
    def delete
      Janeway::Interpreter.new(@query, as: :deleter).interpret(@input)
    end

    # Delete values from the input that are matched by the JSONPath query and also return a truthy value
    # from the block.
    # @return [Array] deleted values
    def delete_if(&block)
      Janeway::Interpreter.new(@query, as: :delete_if, &block).interpret(@input)
    end

    # Assign the given value at every query match.
    # @param replacement [Object]
    # @return [void]
    def replace(replacement = :no_replacement_value_was_given, &block)
      if replacement != :no_replacement_value_was_given && block_given?
        raise Janeway::Error.new('#replace needs either replacement value or block, not both', @query)
      end

      # Avoid infinite loop when the replacement data would also be matched by the query
      previous = []
      each do |_, parent, key|
        # Update the previous match
        unless previous.empty?
          prev_parent, prev_key = *previous
          prev_parent[prev_key] = block_given? ? yield(prev_parent[prev_key]) : replacement
        end

        # Record this match to be updated later
        previous = [parent, key]
      end
      return if previous.empty?

      # Update the final match
      prev_parent, prev_key = *previous
      prev_parent[prev_key] = block_given? ? yield(prev_parent[prev_key]) : replacement
      nil
    end

    # Insert `value` into the input at a location specified by a singular query.
    #
    # This has restrictions:
    #   * Only for singular queries
    #     (no wildcards, filter expressions, child segments, etc.)
    #   * The "parent" node must exist
    #     eg. for $.a[1].name, the path $.a[1] must exist and be a Hash
    #   * Cannot create array index N unless the array
    #     already has exactly N-1 elements
    #   * If query path already exists, the block is called if provided.
    #     Otherwise an exception is raised.
    #
    # Optionally, pass in a block to be called when there is already a value at the
    # specified array index / hash key. The parent object and the array index
    # or hash key will be yielded to the block.
    #
    # @yieldparam [Array, Hash] parent object
    # @yieldparam [Intgeer, String] array index or hash key
    def insert(value, &block)
      # Query must point to a single target object
      unless @query.singular_query?
        msg = 'Janeway::Query#insert may only be used with a singular query'
        raise Janeway::Error.new(msg, @query)
      end

      # Find parent of new value
      parent, key, parent_path = find_parent

      # Insert new value into parent
      case parent
      when Hash then insert_into_hash(parent, key, value, parent_path, &block)
      when Array then insert_into_array(parent, key, value, parent_path, &block)
      else
        raise Error.new("cannot insert into basic type: #{parent.inspect}", @query.to_s)
      end
    end

    private

    # Find the 'parent' of the object pointed to by the query. For singular query only.
    #
    # @!visibility private
    # @return [Object, Object, String] parent object (Hash / Array), key/index (String / Integer), path to parent
    def find_parent
      # Make a Query that points to the target's parent
      parent_query = @query.dup
      selector = parent_query.pop # returns a name or index selector

      # Find parent element, give up if parent does not exist
      results = Interpreter.new(parent_query).interpret(@input)
      case results.size
      when 0 then raise "no parent found for #{@query}, cannot insert value"
      when 1 then parent = results.first
      else raise "query #{parent_query} matched multiple elements!" # not possible for singular query
      end

      [parent, selector.value, parent_query.to_s]
    end

    # Insert value into hash at the given key
    #
    # @!visibility private
    # @param hash [Hash]
    # @param key [String]
    # @param value [Object]
    # @param path [String] jsonpath singular query to parent
    # @yieldparam [Hash] parent object
    # @yieldparam [String] hash key
    def insert_into_hash(hash, key, value, path, &block)
      unless key.is_a?(String) || key.is_a?(Symbol)
        raise Error.new("cannot use #{key.inspect} as hash key", @query.to_s)
      end

      if hash.key?(key)
        raise Error.new("hash at #{path} already has key #{key.inspect}", @query.to_s) unless block_given?

        yield hash, key
      end

      hash[key] = value
    end

    # Insert value into array at the given index
    #
    # @!visibility private
    # @param array [Array]
    # @param index [Integer]
    # @param value [Object]
    # @param path [String] jsonpath singular query to parent
    # @yieldparam [Array] parent object
    # @yieldparam [Integer] array index
    def insert_into_array(array, index, value, path, &block)
      raise Error.new("cannot use #{index.inspect} as array index", @query.to_s) unless index.is_a?(Integer)

      if index < array.size
        raise Error.new("array at #{path} already has index #{index}", @query.to_s) unless block_given?

        yield array, index
      end
      if index > array.size
        raise Error.new("cannot add index #{index} because array at #{path} is too small", @query.to_s)
      end

      array << value
    end
  end
end
