# frozen_string_literal: true

require 'forwardable'

module JsonPath2
  class Token
    extend Forwardable

    attr_reader :type, :lexeme, :literal, :location

    def_delegators :@location, :line, :col, :length

    def initialize(type, lexeme, literal, location)
      @type = type
      @lexeme = lexeme
      @literal = literal
      @location = location
    end

    def to_s
      "Token<#{@type.inspect}, #{@lexeme.inspect}>"
    end
  end
end
