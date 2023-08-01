# frozen_string_literal: true

require_relative 'location'

module JsonPath2
  WHITESPACE = " \t"
  ONE_CHAR_LEX = '$[]()?@:*,-'
  ONE_OR_TWO_CHAR_LEX = %w[. =].freeze
  KEYWORD = [].freeze # FIXME reuse this for function extensions?

  class Lexer
    attr_reader :source, :tokens

    # Tokenize and return the token list.
    # @param query [String] jsonpath query
    # @return [Array<Token>]
    def self.lex(query)
      lexer = new(query)
      lexer.start_tokenization
      lexer.tokens
    end

    def initialize(source)
      @source = source
      @tokens = []
      @line = 0
      @next_p = 0
      @lexeme_start_p = 0
    end

    def start_tokenization
      tokenize while source_uncompleted?

      tokens << Token.new(:eof, '', nil, after_source_end_location)
    end

    # FIXME: why? why not just use regular instance vars?
    attr_accessor :line, :next_p, :lexeme_start_p

    # Read a token from the @source, increment the pointers.
    def tokenize
      self.lexeme_start_p = next_p

      c = consume

      return if WHITESPACE.include?(c)
      return ignore_comment_line if c == '#'

      if c == "\n"
        self.line += 1
        tokens << token_from_one_char_lex(c) if tokens.last&.type != :"\n"

        return
      end

      token =
        if ONE_CHAR_LEX.include?(c)
          token_from_one_char_lex(c)
        elsif ONE_OR_TWO_CHAR_LEX.include?(c)
          token_from_one_or_two_char_lex(c)
        elsif c == '"'
          string
        elsif digit?(c)
          number
        elsif alpha_numeric?(c)
          identifier
        end

      raise("Unknown character: #{c.inspect}") unless token

      tokens << token
    end

    DIGITS = '0123456789'
    def digit?(lexeme)
      return true if DIGITS.include?(lexeme)
    end

    ALPHA = ('a'..'z').to_a.concat(('A'..'Z').to_a)
    def alpha_numeric?(lexeme)
      return true if ALPHA.include?(lexeme)
    end

    def lookahead(offset = 1)
      lookahead_p = (next_p - 1) + offset
      return "\0" if lookahead_p >= source.length

      source[lookahead_p]
    end

    def token_from_one_char_lex(lexeme)
      Token.new(lexeme.to_sym, lexeme, nil, current_location)
    end

    # Consumes =, ==, . or ..
    # @return [Token]
    def token_from_one_or_two_char_lex(lexeme)
      nxt = lookahead
      if nxt == lexeme
        consume
        Token.new((lexeme + nxt).to_sym, lexeme + nxt, nil, current_location)
      else
        token_from_one_char_lex(lexeme)
      end
    end

    def consume
      c = lookahead
      self.next_p += 1
      c
    end

    def consume_digits
      consume while digit?(lookahead)
    end

    def string
      while lookahead != '"' && source_uncompleted?
        self.line += 1 if lookahead == "\n"
        consume
      end
      raise 'Unterminated string error.' if source_completed?

      consume # consuming the closing '"'.
      lexeme = source[(lexeme_start_p)..(next_p - 1)]
      # the actual value of the string is the content between the double quotes.
      literal = source[(lexeme_start_p + 1)..(next_p - 2)]

      Token.new(:string, lexeme, literal, current_location)
    end

    # Consume a numeric string
    # FIXME handle negative
    def number
      consume_digits

      # Look for a fractional part.
      if lookahead == '.'
        raise "Decimal digits are not handled: #{lexeme}#{lookahead}"
      end

      lexeme = source[lexeme_start_p..(next_p - 1)]
      Token.new(:number, lexeme, lexeme.to_i, current_location)
    end

    # Consume an alphanumeric string
    def identifier
      consume while alpha_numeric?(lookahead)

      identifier = source[lexeme_start_p..(next_p - 1)]
      type =
        if KEYWORD.include?(identifier)
          identifier.to_sym
        else
          :identifier
        end

      Token.new(type, identifier, identifier, current_location)
    end

    def source_completed?
      next_p >= source.length # our pointer starts at 0, so the last char is length - 1.
    end

    def source_uncompleted?
      !source_completed?
    end

    def current_location
      Location.new(line, lexeme_start_p, next_p - lexeme_start_p)
    end

    def after_source_end_location
      Location.new(line, next_p, 1)
    end
  end
end
