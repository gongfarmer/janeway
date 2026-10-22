# frozen_string_literal: true

require 'forwardable'

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
