# frozen_string_literal: true

require 'forwardable'

module JsonPath2
  class Token
    extend Forwardable

    attr_reader :type, :lexeme, :location

    # write-access so '-' operator can modify number value
    attr_accessor :literal

    def_delegators :@location, :line, :col, :length

    def initialize(type, lexeme, literal, location)
      @type = type
      @lexeme = lexeme
      @literal = literal
      @location = location
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
        @type == other.type && @lexeme == other.lexem && @literal = other.literal
      else
        raise ArgumentError, "don't know how to compare Token with #{other.inspect}"
      end
    end
  end
end
