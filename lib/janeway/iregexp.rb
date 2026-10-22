# frozen_string_literal: true

require_relative 'error'

module Janeway
  # Validates an I-Regexp and translates it to an equivalent Ruby Regexp.
  #
  # The pattern is parsed with the grammar from RFC 9485 section 3, and the Ruby source is emitted
  # while parsing, so a pattern that is not an I-Regexp never reaches Regexp.new, and characters
  # that Ruby treats as syntax but I-Regexp treats as ordinary characters are escaped.
  #
  # The limits below are this library's own choices. RFC 9485 section 8 allows an implementation to
  # limit range quantifiers in composability and range, but gives no values.
  # @see https://www.rfc-editor.org/rfc/rfc9485.html
  module IRegexp
    # Longest pattern accepted, in characters.
    MAX_LENGTH = 10_000

    # Largest number accepted in a range quantifier such as a{2,4}.
    MAX_REPEAT = 1_000

    # Deepest nesting of groups accepted. This also bounds the recursion depth of the parser.
    MAX_GROUP_DEPTH = 100

    # Seconds a single match may take, where the Ruby version supports a per-regexp timeout (3.2+).
    MATCH_TIMEOUT = 1

    # Regexp.new accepts the timeout: keyword from Ruby 3.2, which is also when Regexp.timeout appeared.
    # Probe with respond_to? and not by trying the keyword: on an older Ruby a trailing hash would be
    # read as the positional options argument, and a pattern would silently become case-insensitive.
    TIMEOUT_SUPPORTED = Regexp.respond_to?(:timeout)

    # Error raised when a match exceeds MATCH_TIMEOUT. Regexp::TimeoutError only exists on Ruby 3.2+,
    # elsewhere this is a class that is never raised for that reason.
    TIMEOUT_ERROR = defined?(Regexp::TimeoutError) ? Regexp::TimeoutError : Class.new(StandardError)

    # Unicode general category names, from the IsCategory production of RFC 9485 section 3.
    CATEGORY = /\A(?:L[lmotu]?|M[cen]?|N[dlo]?|P[c-fios]?|Z[lps]?|S[ckmo]?|C[cfno]?)\z/

    # Raised for a pattern that is not an I-Regexp.
    class Invalid < Janeway::Error
      # @return [Integer, nil] index of the problem in the pattern, nil when there is no single place
      attr_reader :offset

      # @param msg [String]
      # @param offset [Integer, nil]
      def initialize(msg, offset = nil)
        super(msg)
        @offset = offset
      end
    end

    # Raised for an I-Regexp that exceeds one of the limits above.
    class LimitExceeded < Janeway::Error
      # @return [Integer, nil] index of the problem in the pattern, nil when there is no single place
      attr_reader :offset

      # @return [Integer] number of pattern characters the problem covers
      attr_reader :length

      # @param msg [String]
      # @param offset [Integer, nil]
      # @param length [Integer]
      def initialize(msg, offset = nil, length = 1)
        super(msg)
        @offset = offset
        @length = length
      end
    end

    # Validate an I-Regexp and translate it to a Ruby Regexp.
    #
    # @param iregex [String]
    # @param anchor [Boolean] add anchors to match the string start and end
    # @return [Regexp]
    # @raise [Invalid] the pattern is not an I-Regexp
    # @raise [LimitExceeded] the pattern is an I-Regexp, but is over one of the limits
    def self.compile(iregex, anchor: true)
      body = Parser.new(iregex).parse
      # RFC 9485 section 5.4: enclose the regexp in \A(?: and )\z.
      body = "\\A(?:#{body})\\z" if anchor
      begin
        TIMEOUT_SUPPORTED ? Regexp.new(body, timeout: MATCH_TIMEOUT) : Regexp.new(body)
      rescue RegexpError => e
        # Ruby refuses some patterns that are valid I-Regexp, e.g. a{3,2}
        raise Invalid, e.message
      end
    end

    # Escape sequences that the lexer turns into one character, see Lexer#consume_escape_sequence.
    SHORT_ESCAPES = 'bfnrt/\\"\''

    # Find the column in the query of a character in a string literal's value.
    #
    # The token's value has its escape sequences decoded, so an index into the value is not an index
    # into the query when the string contains escapes. This walks the lexeme, which is the query text.
    # @param token [Token] string token
    # @param index [Integer] index of a character in the token's decoded value
    # @return [Integer, nil] column of the character in the query, nil if it cannot be found
    def self.query_column(token, index)
      lexeme = token.lexeme
      pos = 1 # skip the opening quote
      index.times { pos += escape_length(lexeme, pos) }
      return nil if pos >= lexeme.length - 1 # at or past the closing quote

      token.location.col + pos
    end

    # @return [Integer] number of characters in the lexeme taken by the character that starts at pos
    def self.escape_length(lexeme, pos)
      return 1 unless lexeme[pos] == '\\'
      return 2 if SHORT_ESCAPES.include?(lexeme[pos + 1])

      # \uXXXX is 6 characters. A high surrogate followed by \uXXXX is one character in 12.
      high = lexeme[pos + 2, 4].to_s.match?(/\Ad[89ab]/i)
      high && lexeme[pos + 6, 2] == '\\u' ? 12 : 6
    end

    # Recursive-descent parser for the ABNF of RFC 9485 section 3, which builds the Ruby regexp source.
    # Each method is named for the production it implements.
    class Parser
      # Characters allowed after a backslash. RFC 9485 section 3, SingleCharEsc.
      SINGLE_CHAR_ESC = '()*+-.?[]^nrt{|}\\'

      # @param iregex [String]
      def initialize(iregex)
        @original = iregex
        @src = iregex.valid_encoding? ? iregex.chars : [] # array: indexing a multibyte String is O(n)
        @i = 0
        @out = +''
        @depth = 0
        @has_range = false # does the group being parsed contain a range quantifier?
        @limit = nil # first limit violation, raised only if the pattern is otherwise valid
      end

      # @return [String] Ruby regexp source, without anchors
      # @raise [Invalid, LimitExceeded]
      def parse
        # RFC 9485 section 1: a pattern is a sequence of Unicode scalar values. Accept UTF-8, and US-ASCII
        # which is a subset of it. Any other encoding is refused and not transcoded, and that includes a
        # binary (ASCII-8BIT) string even when its bytes are all ASCII.
        unless [Encoding::UTF_8, Encoding::US_ASCII].include?(@original.encoding) && @original.valid_encoding?
          raise Invalid, 'pattern is not valid UTF-8'
        end

        i_regexp
        raise Invalid.new("unexpected #{@src[@i].inspect}", @i) if @i < @src.length

        limit("pattern is longer than #{MAX_LENGTH} characters", nil) if @src.length > MAX_LENGTH
        raise @limit if @limit

        @out
      end

      private

      def peek
        @src[@i]
      end

      # Grammar errors take precedence over limit errors, so a limit violation is remembered and
      # only raised once the whole pattern is known to be an I-Regexp.
      def limit(msg, offset, length = 1)
        @limit ||= LimitExceeded.new(msg, offset, length)
      end

      # i-regexp = branch *( "|" branch )
      def i_regexp
        branch
        while peek == '|'
          @i += 1
          @out << '|'
          branch
        end
      end

      # branch = *piece
      def branch
        piece while !peek.nil? && peek != '|' && peek != ')'
      end

      # piece = atom [ quantifier ]
      def piece
        contains_range = atom
        quantifier(contains_range)
      end

      # atom = NormalChar / charClass / ( "(" i-regexp ")" )
      # @return [Boolean] true if the atom is a group that contains a range quantifier
      def atom
        case peek
        when '(' then return group
        when '[' then char_class
        when '.'
          # RFC 9485 section 5.4: replace an unescaped dot outside a character class with [^\n\r]
          @i += 1
          @out << '[^\n\r]'
        when '\\' then escape
        else normal_char(in_class: false)
        end
        false
      end

      # @return [Boolean] true if the group contains a range quantifier
      def group
        open = @i
        @i += 1
        @depth += 1
        raise LimitExceeded.new("groups are nested deeper than #{MAX_GROUP_DEPTH}", open) if @depth > MAX_GROUP_DEPTH

        @out << '(?:'
        outer_has_range = @has_range
        @has_range = false
        i_regexp
        raise Invalid.new('unterminated group', @i) unless peek == ')'

        @i += 1
        @depth -= 1
        @out << ')'
        inner_has_range = @has_range
        @has_range = outer_has_range || inner_has_range
        inner_has_range
      end

      # quantifier = ( "*" / "+" / "?" ) / range-quantifier
      def quantifier(contains_range)
        case peek
        when '*', '+', '?'
          @out << peek
          @i += 1
        when '{' then range_quantifier(contains_range)
        end
      end

      # range-quantifier = "{" QuantExact [ "," [ QuantExact ] ] "}"
      # QuantExact = 1*%x30-39
      #
      # RFC 9485 section 8 allows limiting range quantifiers in range and in composability: here a
      # number above MAX_REPEAT, and a range quantifier applied to a group that contains one.
      def range_quantifier(contains_range)
        start = @i
        counts, finish = scan_range_quantifier(start)
        raise Invalid.new('malformed range quantifier', start) unless counts

        counts.each do |digits, offset|
          next if digits.empty? || digits.to_i <= MAX_REPEAT

          limit("repeat count #{digits} exceeds #{MAX_REPEAT}", offset, digits.length)
        end
        limit('range quantifier applied to a group that contains a range quantifier', start) if contains_range
        @has_range = true
        @out << @src[start...finish].join
        @i = finish
      end

      # Match \{(\d+)(?:,(\d*))?\} at start by scanning the character array, which a Regexp cannot
      # do in O(1) per call on a multibyte string. The digit runs can be long, so no fixed-size slice.
      # @return [Array, nil] [[[digits, offset], ...], index after the closing brace], nil if malformed
      def scan_range_quantifier(start)
        return nil unless @src[start] == '{'

        first_start = start + 1
        first_end = digits_end(first_start)
        return nil if first_end == first_start # QuantExact needs at least one digit

        counts = [[@src[first_start...first_end].join, first_start]]
        pos = first_end
        if @src[pos] == ','
          second_start = pos + 1
          pos = digits_end(second_start)
          counts << [@src[second_start...pos].join, second_start]
        end
        @src[pos] == '}' ? [counts, pos + 1] : nil
      end

      # @return [Integer] index of the first character at or after pos that is not an ASCII digit
      def digits_end(pos)
        pos += 1 while @src[pos]&.match?(/\A[0-9]\z/)
        pos
      end

      # charClassExpr = "[" [ "^" ] ( "-" / CCE1 ) *CCE1 [ "-" ] "]"
      def char_class
        open = @i
        @i += 1
        @out << '['
        negated = peek == '^'
        if negated
          @i += 1
          @out << '^'
        end
        # RFC 9485 section 3: charClassExpr is not allowed to match [^]
        raise Invalid.new('empty negated character class [^]', open) if negated && peek == ']'
        # RFC 9485 section 3: charClassExpr has at least one item, so [] is not allowed either
        raise Invalid.new('empty character class []', open) if peek == ']'

        first = true
        until peek == ']'
          raise Invalid.new('unterminated character class', @i) if peek.nil?

          class_item(first)
          first = false
        end
        @i += 1
        @out << ']'
      end

      # CCE1 = ( CCchar [ "-" CCchar ] ) / charClassEsc, RFC 9485 section 3
      def class_item(first)
        if peek == '-'
          # a "-" is only a plain character at the start or the end of the class
          raise Invalid.new("misplaced '-' in character class", @i) unless first || @src[@i + 1] == ']'

          @i += 1
          @out << '\-'
        elsif peek == '\\' && %w[p P].include?(@src[@i + 1])
          # charClassEsc is not a CCchar, so it takes no range: a following "-" is rejected by the next item
          escape
        else
          cc_char
          class_range_end if peek == '-' && @src[@i + 1] != ']'
        end
      end

      # "-" CCchar, the end of a range. RFC 9485 section 3, CCE1.
      def class_range_end
        @i += 1
        @out << '-'
        raise Invalid.new('unterminated range in character class', @i) if peek.nil? || peek == ']'

        cc_char
      end

      # CCchar = ( %x00-2C / %x2E-5A / %x5E-D7FF / %xE000-10FFFF ) / SingleCharEsc
      # RFC 9485 section 3: a SingleCharEsc is a CCchar, so it can start or end a range.
      def cc_char
        if peek == '\\' then escape(single_char_only: true)
        else normal_char(in_class: true)
        end
      end

      # NormalChar (outside a class) and CCchar (inside a class). RFC 9485 section 3.
      # In I-Regexp "^" and "$" are ordinary characters, not anchors: the RFC 9485 author confirmed
      # this, see https://github.com/jsonpath-standard/jsonpath-compliance-test-suite (open issue).
      def normal_char(in_class:)
        char = peek
        raise Invalid.new('unexpected end of pattern', @i) if char.nil?
        raise Invalid.new("character #{char.inspect} must be escaped", @i) unless allowed_char?(char.ord, in_class)

        @i += 1
        # Regexp.escape does not escape "&", but Ruby reads "&&" in a class as set intersection
        @out << (char == '&' ? '\&' : Regexp.escape(char))
      end

      # @param code [Integer] code point
      def allowed_char?(code, in_class)
        return false if (0xD800..0xDFFF).cover?(code) # surrogates

        if in_class
          # CCchar: %x00-2C / %x2E-5A / %x5E-D7FF / %xE000-10FFFF
          code <= 0x2C || (0x2E..0x5A).cover?(code) || code >= 0x5E
        else
          # NormalChar: %x00-27 / "," / "-" / %x2F-3E / %x40-5A / %x5E-7A / %x7E-D7FF / %xE000-10FFFF
          code <= 0x27 || [0x2C, 0x2D].include?(code) || (0x2F..0x3E).cover?(code) ||
            (0x40..0x5A).cover?(code) || (0x5E..0x7A).cover?(code) || code >= 0x7E
        end
      end

      # SingleCharEsc / catEsc / complEsc
      # @param single_char_only [Boolean] refuse catEsc and complEsc, where a CCchar is required
      def escape(single_char_only: false)
        start = @i
        nxt = @src[@i + 1]
        raise Invalid.new('trailing backslash', start) if nxt.nil?

        if %w[p P].include?(nxt)
          raise Invalid.new("\\#{nxt} is not allowed here, only a single-character escape", start) if single_char_only

          category_escape(start)
        elsif SINGLE_CHAR_ESC.include?(nxt)
          @i += 2
          @out << { 'n' => '\n', 'r' => '\r', 't' => '\t' }.fetch(nxt) { "\\#{nxt}" }
        else
          raise Invalid.new("invalid escape \\#{nxt}", start)
        end
      end

      # catEsc = %s"\p{" charProp "}" ; complEsc = %s"\P{" charProp "}"
      def category_escape(start)
        # at most \p{Xx}, 6 characters
        m = /\A\\[pP]\{([A-Za-z]{1,2})\}/.match(@src[start, 6].join)
        raise Invalid.new('malformed category escape', start) unless m && CATEGORY.match?(m[1])

        @i = start + m[0].length
        @out << m[0]
      end
    end
  end
end
