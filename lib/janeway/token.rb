# frozen_string_literal: true

require 'forwardable'
require_relative 'location'

module Janeway
  # Tokens are produced by the lexer, they represent jsonpath query elements in a low-level, non-hierarchical way.
  class Token
    extend Forwardable

    attr_reader :type, :lexeme, :literal, :location

    # For a string token, the index within the lexeme of each character of the decoded literal,
    # so lexeme[offsets[i]] is where literal[i] came from. It differs from i when the string
    # contains escape sequences or the lexeme starts with a quote. Nil for other token types.
    # @return [Array<Integer>, nil]
    attr_reader :offsets

    def_delegators :@location, :line, :col, :length

    def initialize(type, lexeme, literal, location, offsets = nil)
      @type = type
      @lexeme = lexeme
      @literal = literal
      @location = location
      @offsets = offsets
    end

    # Find where a character of a string token's decoded value came from in the query.
    #
    # Relies on two invariants: offsets[i] is the index within the lexeme of the start of literal[i],
    # and location.col is the column of the lexeme in the query.
    # @param index [Integer] index of a character in the decoded value
    # @return [Integer, nil] column in the query of that character (or of the backslash that starts its
    #   escape); nil when the token has no offsets, or no character at that index
    def column_of(index)
      return nil if @offsets.nil? || !index.between?(0, @offsets.length - 1)

      offset = @offsets[index]
      offset && (@location.col + offset)
    end

    # Find where a run of characters of a string token's decoded value came from in the query.
    # @param offset [Integer, nil] index in the decoded value of the first character
    # @param length [Integer, nil] number of decoded characters, treated as 1 if nil or not positive
    # @return [Location] from the first character to the start of the last one; the location of the whole
    #   token when offset is nil or the range cannot be found in the token
    def location_of(offset, length = 1)
      return @location unless offset

      length = 1 unless length&.positive?
      first = column_of(offset)
      last = column_of(offset + length - 1)
      return @location unless first && last

      Location.new(first, last - first + 1)
    end

    def to_s
      "Token<#{@type}: #{@lexeme.inspect}>"
    end

    def ==(other)
      # This is intended to make unit test expectations simple to define, experimental, may drop
      case other
      when Integer, String then @literal == other
      when Symbol then @type == other
      when Token
        @type == other.type && @lexeme == other.lexeme && @literal == other.literal
      else
        raise ArgumentError, "don't know how to compare Token with #{other.inspect}"
      end
    end
  end
end
