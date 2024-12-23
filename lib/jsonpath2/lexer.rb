# frozen_string_literal: true

require_relative 'location'
require_relative 'token'

module JsonPath2
  WHITESPACE = " \t"
  ONE_CHAR_LEX = '$[]()?@:*,-'
  ONE_OR_TWO_CHAR_LEX = %w[. =].freeze
  KEYWORD = [].freeze # FIXME: reuse this for function extensions?

  # Transforms source code into tokens
  class Lexer
    attr_reader :source, :tokens

    # Tokenize and return the token list.
    # @param query [String] jsonpath query
    # @return [Array<Token>]
    def self.lex(query)
      raise ArgumentError, "expect string, got #{query.inspect}" unless query.is_a?(String)

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
        elsif %w[" '].include?(c)
          delimited_string(c)
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
      DIGITS.include?(lexeme)
    end

    ALPHA = ('a'..'z').to_a.concat(('A'..'Z').to_a)
    def alpha_numeric?(lexeme)
      ALPHA.include?(lexeme)
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

    # @param delimiter [String] eg. ' or "
    # @return [Token] string token
    def delimited_string(delimiter)
      literal_chars = []
      while lookahead != delimiter && source_uncompleted?
        self.line += 1 if lookahead == "\n" # FIXME: do jsonpath queries have lines? Find out when implementing functions

        # Transform escaped representation to literal chars
        literal_chars <<
          if lookahead == '\\'
            consume_escape_sequence # consumes multiple chars
          else
            consume
          end
      end
      raise "Unterminated string error: #{literal_chars.join.inspect}" if source_completed?

      consume # closing delimiter

      # literal value omits delimiters and includes un-escaped values
      literal = literal_chars.join

      # lexeme value includes delimiters and literal escape characters
      lexeme = source[lexeme_start_p..(next_p - 1)]

      Token.new(:string, lexeme, literal, current_location)
    end

    # Read escape char literals, and transform them into the described character
    # @return [String] single character (possibly multi-byte)
    def consume_escape_sequence
      raise 'not an escape sequence' unless consume == '\\'

      char = consume
      case char
      when 'b' then "\b"
      when 't' then "\t"
      when 'n' then "\n"
      when 'f' then "\f"
      when 'r' then "\r"
      when '"', "'", '\\' then char
      when 'u' then consume_unicode_escape_sequence
      else
        raise "unknown escape sequence: \\#{char}"
      end
    end

    # Read unicode escape sequence consisting of 4 hex digits.
    # Both lower and uppercase are allowed.
    # The `\u` prefix has already been consumed
    #
    # @return [String] single character (possibly multi-byte)
    def consume_unicode_escape_sequence
      hex_digits = []
      4.times do
        hex_digits << consume
        case hex_digits.last.ord
        when 0x30..0x39 then next # '0'..'1'
        when 0x40..0x46 then next # 'A'..'F'
        when 0x61..0x66 then next # 'a'..'f'
        else
          raise "invalid unicode escape sequence: \\u#{hex_digits.join}"
        end
      end
      raise "incomplete unicode escape sequence: \\u#{hex_digits.join}" if hex_digits.size < 4

      hex_digits.join.hex.chr('UTF-8')
    end

    # Consume a numeric string
    # FIXME handle negative... here or in parser?
    def number
      consume_digits
      lexeme = source[lexeme_start_p..(next_p - 1)]

      # Look for a fractional part.
      raise "Decimal digits are not handled: #{lexeme}#{lookahead}" if lookahead == '.'

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
