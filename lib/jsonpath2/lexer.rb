# frozen_string_literal: true

require_relative 'location'
require_relative 'token'

module JsonPath2
  OPERATORS = {
    and: '&&',
    array_slice_separator: ':',
    child_end: ']',
    child_start: '[',
    current_node: '@',
    descendants: '..',
    dot: '.',
    equal: '==',
    filter: '?',
    greater_than: '>',
    greater_than_or_equal: '>=',
    group_end: ')',
    group_start: '(',
    less_than: '<',
    less_than_or_equal: '<=',
    minus: '-',
    not: '!',
    not_equal: '!=',
    or: '||',
    root: '$',
    union: ',',
    wildcard: '*',
  }.freeze
  ONE_CHAR_LEX = OPERATORS.values.select { |lexeme| lexeme.size == 1 }.freeze
  TWO_CHAR_LEX = OPERATORS.values.select { |lexeme| lexeme.size == 2 }.freeze
  TWO_CHAR_LEX_FIRST = TWO_CHAR_LEX.map { |lexeme| lexeme[0] }.freeze
  ONE_OR_TWO_CHAR_LEX = ONE_CHAR_LEX & TWO_CHAR_LEX.map { |str| str[0] }.freeze

  WHITESPACE = " \t"
  KEYWORD = %w[true false null].freeze
  FUNCTIONS = %w[length count match search value].freeze

  # Benchmarking shows it is faster to check membership in a string than an array (ruby 3.1)
  ALPHABET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  DIGITS = '0123456789'
  ALPHABET_OR_UNDERSCORE = "#{ALPHABET}_".freeze

  # Transforms source code into tokens
  class Lexer
    attr_reader :source, :tokens
    attr_accessor :next_p, :lexeme_start_p

    # Tokenize and return the token list.
    #
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
      @next_p = 0
      @lexeme_start_p = 0
    end

    def start_tokenization
      tokenize while source_uncompleted?

      tokens << Token.new(:eof, '', nil, after_source_end_location)
    end

    # Read a token from the @source, increment the pointers.
    def tokenize
      self.lexeme_start_p = next_p

      c = consume
      return if WHITESPACE.include?(c)

      token =
        if ONE_OR_TWO_CHAR_LEX.include?(c)
          token_from_one_or_two_char_lex(c)
        elsif ONE_CHAR_LEX.include?(c)
          token_from_one_char_lex(c)
        elsif TWO_CHAR_LEX_FIRST.include?(c)
          token_from_two_char_lex(c)
        elsif %w[" '].include?(c)
          lex_delimited_string(c)
        elsif digit?(c)
          lex_number
        elsif name_first_char?(c)
          lex_member_name_shorthand(ignore_keywords: tokens.last.type == :dot)
        end
        # FIXME: what about string that starts with unicode?  Seems like #alpha_numeric? does not handle this

      raise("Unknown character: #{c.inspect}") unless token

      tokens << token
    end

    def digit?(lexeme)
      DIGITS.include?(lexeme)
    end

    def alpha_numeric?(lexeme)
      ALPHABET.include?(lexeme) || DIGITS.include?(lexeme)
    end

    def lookahead(offset = 1)
      lookahead_p = (next_p - 1) + offset
      return "\0" if lookahead_p >= source.length

      source[lookahead_p]
    end

    def token_from_one_char_lex(lexeme)
      Token.new(OPERATORS.key(lexeme), lexeme, nil, current_location)
    end

    # Consumes an operator that could be either 1 or 2 chars in length
    # @return [Token]
    def token_from_one_or_two_char_lex(lexeme)
      next_two_chars = [lexeme, lookahead].join
      if TWO_CHAR_LEX.include?(next_two_chars)
        consume
        Token.new(OPERATORS.key(next_two_chars), next_two_chars, nil, current_location)
      else
        token_from_one_char_lex(lexeme)
      end
    end

    # Consumes a 2 char operator
    # @return [Token]
    def token_from_two_char_lex(lexeme)
      next_two_chars = [lexeme, lookahead].join
      raise "unknown operator: #{next_two_chars.inspect}" unless TWO_CHAR_LEX.include?(next_two_chars)

      consume
      Token.new(OPERATORS.key(next_two_chars), next_two_chars, nil, current_location)
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
    def lex_delimited_string(delimiter)
      literal_chars = []
      while lookahead != delimiter && source_uncompleted?
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

    # Consume a numeric string. May be an integer, fractional, or exponent.
    #   number = (int / "-0") [ frac ] [ exp ] ; decimal number
    #   frac   = "." 1*DIGIT                   ; decimal fraction
    #   exp    = "e" [ "-" / "+" ] 1*DIGIT     ; decimal exponent
    def lex_number
      consume_digits

      # Look for a fractional part
      if lookahead == '.' && digit?(lookahead(2))
        consume # "."
        consume_digits
      end

      # Look for an exponent part
      if lookahead == 'e' && %w[+ -].include?(lookahead(2))
        consume # "e"
        consume # "+" / "-"
        consume_digits
      end

      lexeme = source[lexeme_start_p..(next_p - 1)]
      literal =
        if lexeme.include?('.') || lexeme.include?('e')
          lexeme.to_f
        else
          lexeme.to_i
        end
      Token.new(:number, lexeme, literal, current_location)
    end

    # Consume an alphanumeric string.
    # If `ignore_keywords`, the result is alway an :identifier token.
    # Otherwise, keywords and function names will be recognized and tokenized as those types.
    #
    # @param ignore_keywords [Boolean]
    def lex_identifier(ignore_keywords: false)
      consume while alpha_numeric?(lookahead)

      identifier = source[lexeme_start_p..(next_p - 1)]
      type =
        if KEYWORD.include?(identifier) && !ignore_keywords
          identifier.to_sym
        elsif FUNCTIONS.include?(identifier) && !ignore_keywords
          :function
        else
          :identifier
        end

      Token.new(type, identifier, identifier, current_location)
    end

    # Parse an identifier string which is not within delimiters.
    # The standard set of unicode code points are allowed.
    # No character escapes are allowed.
    # Keywords and function names are ignored in this context.
    # @return [Token]
    def lex_unescaped_identifier
      consume while unescaped?(lookahead)
      identifier = source[lexeme_start_p..(next_p - 1)]
      Token.new(:identifier, identifier, identifier, current_location)
    end

    # Return true if string matches the definition of "unescaped" from RFC9535:
    # unescaped     = %x20-21 /        ; see RFC 8259
    #                    ; omit 0x22 "
    #                 %x23-26 /
    #                    ; omit 0x27 '
    #                 %x28-5B /
    #                    ; omit 0x5C \
    #                 %x5D-D7FF /
    #                    ; skip surrogate code points
    #                 %xE000-10FFFF
    # @param char [String] single character, possibly multi-byte
    def unescaped?(char)
      case char.ord
      when 0x20..0x21 then true # space, "!"
      when 0x23..0x26 then true # "#", "$", "%"
      when 0x28..0x5B then true # "(" ... "["
      when 0x5D..0xD7FF then true # remaining ascii and lots of unicode code points
        # omit surrogate code points
      when 0xE000..0x10FFFF then true # much more unicode code points
      else false
      end
    end

    def escapable?(char)
      case char.ord
      when 0x62 then true # backspace
      when 0x66 then true # form feed
      when 0x6E then true # line feed
      when 0x72 then true # carriage return
      when 0x74 then true # horizontal tab
      when 0x2F then true # slash
      when 0x5C then true # backslash
      else false
      end
    end

    # True if character is suitable as the first character in a name selector
    # using shorthand notation (ie. no bracket notation.)
    #
    # Defined in RFC9535 by ths ABNF grammar:
    # name-first    = ALPHA /
    #                 "_"   /
    #                 %x80-D7FF /
    #                    ; skip surrogate code points
    #                 %xE000-10FFFF
    #
    # @param char [String] single character, possibly multi-byte
    # @return [Boolean]
    def name_first_char?(char)
      ALPHABET_OR_UNDERSCORE.include?(char) \
        || (0x80..0xD7FF).cover?(char.ord) \
        || (0xE000..0x10FFFF).cover?(char.ord)
    end

    # True if character is acceptable in a name selector using shorthand notation (ie. no bracket notation.)
    # This is the same set as #name_first_char? except that it also allows numbers
    # @param char [String] single character, possibly multi-byte
    # @return [Boolean]
    def name_char?(char)
      ALPHABET_OR_UNDERSCORE.include?(char) \
        || DIGITS.include?(char) \
        || (0x80..0xD7FF).cover?(char.ord) \
        || (0xE000..0x10FFFF).cover?(char.ord)
    end

    # Lex a member name that is found within dot notation.
    #
    # Recognize keywords and given them the correct type.
    # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.5.1.1-3
    #
    # @param ignore_keywords [Boolean]
    # @return [Token]
    def lex_member_name_shorthand(ignore_keywords: false)
      consume while name_char?(lookahead)
      identifier = source[lexeme_start_p..(next_p - 1)]
      type =
        if KEYWORD.include?(identifier) && !ignore_keywords
          identifier.to_sym
        elsif FUNCTIONS.include?(identifier) && !ignore_keywords
          :function
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
      Location.new(lexeme_start_p, next_p - lexeme_start_p)
    end

    def after_source_end_location
      Location.new(next_p, 1)
    end
  end
end
