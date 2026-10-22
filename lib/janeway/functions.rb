# frozen_string_literal: true

require_relative 'ast/function'
require_relative 'ast/string_type'
require_relative 'iregexp'

module Janeway
  # Mixin to provide JSONPath function handlers for Parser, plus the built-in function registry.
  module Functions
    # Reject a literal pattern that exceeds an I-Regexp limit, at the point where the query is parsed.
    #
    # A literal that is not an I-Regexp is not an error: match() and search() return LogicalFalse
    # for it, see build_regex_body. A literal over a limit is a valid I-Regexp that this library
    # refuses to run, so the user is told, with the position in the query.
    # @see https://www.rfc-editor.org/rfc/rfc9485.html#name-security-considerations
    #   RFC 9485 section 8: an implementation may limit range quantifiers in range and composability
    # @param parameter [AST::Expression] the second parameter of match() or search(), just parsed
    # @raise [Janeway::Error]
    def validate_literal_pattern(parameter)
      return unless parameter.is_a?(AST::StringType)

      IRegexp.compile(parameter.value)
    rescue IRegexp::Invalid
      nil # RFC 9535 section 2.4.6: the function returns LogicalFalse, see build_regex_body
    rescue IRegexp::LimitExceeded => e
      raise Error.new("I-Regexp #{e.message}", @jsonpath, pattern_location(parameter.token, e))
    end

    # Find where in the query the problem in a pattern is.
    # @param token [Token, nil] string token of the pattern
    # @param error [IRegexp::LimitExceeded]
    # @return [Location, nil] position of the problem, or of the whole string when it has no single
    #   position; nil when the literal has no token to locate it by
    def pattern_location(token, error)
      return nil unless token
      return token.location unless error.offset

      first = query_column(token, error.offset)
      last = query_column(token, error.offset + error.length - 1)
      return token.location unless first && last

      Location.new(first, last - first + 1)
    end

    # @param token [Token] string token
    # @param index [Integer] index of a character in the token's decoded value
    # @return [Integer, nil] column of that character in the query, nil if the token has no such offset
    def query_column(token, index)
      offset = token.offsets&.[](index)
      offset && (token.location.col + offset)
    end

    # All jsonpath function parameters are one of these accepted types.
    # Parse the function parameter and return the result.
    # @return [String, AST::CurrentNode, AST::RootNode]
    def parse_function_parameter
      result =
        case current.type
        when :string then parse_string
        when :current_node then parse_current_node
        when :root then parse_root
        when :group_end then raise Error, 'Function call is missing parameter'
        else
          # Invalid, no function uses this.
          # Instead of crashing here, accept it and let the function return an empty result.
          parse_expr
        end
      consume
      result
    end

    # Largest number of distinct document-supplied patterns that one function call remembers.
    DYNAMIC_PATTERN_CACHE_SIZE = 100

    # Build a match/search body. When the pattern is a StringType literal we
    # compile the regex once, when the interpreter is built.
    # Otherwise the pattern comes from the input document and is compiled when it is first used.
    #
    # A pattern that is not an I-Regexp, or that exceeds a limit, gives LogicalFalse.
    # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-match-function-extension
    #   RFC 9535 section 2.4.6: "If the first argument is not a string or the second argument is
    #   not a string conforming to [RFC9485], the result is LogicalFalse." Section 2.4.7 says the
    #   same for search().
    # A literal that exceeds a limit has already been rejected by the parser, see
    # Functions#validate_literal_pattern.
    def self.build_regex_body(parameters, anchor:)
      literal = parameters[1].is_a?(AST::StringType) ? parameters[1].value : nil
      # The cache holds compiled regexps keyed by pattern text, so reusing it for other subjects is
      # correct. It lives as long as the interpreter tree, which Query#interpreter_tree_for caches
      # on an unfrozen Query.
      cache = {} # pattern string => Regexp, or nil when the pattern is unusable
      cache[literal] = compile_or_nil(literal, anchor) if literal # a literal is compiled once, now
      lambda do |str, pattern|
        pattern = literal if literal
        next false unless str.is_a?(String) && pattern.is_a?(String)
        # A pattern in the wrong encoding is false and never reaches the cache: Hash lookup compares
        # strings by content, so a binary 'a' would otherwise share the entry of a UTF-8 'a'.
        next false unless IRegexp.valid_encoding?(pattern)

        unless cache.key?(pattern)
          cache.shift if cache.size >= DYNAMIC_PATTERN_CACHE_SIZE
          cache[pattern] = compile_or_nil(pattern, anchor)
        end

        !cache[pattern].nil? && match_safely(cache[pattern], str)
      end
    end

    # RFC 9535 section 2.4.6: a pattern that does not conform to RFC 9485 gives LogicalFalse, so it is nil here.
    # A pattern over a limit (RFC 9485 section 8) is treated the same way.
    # @return [Regexp, nil] nil when the pattern is not usable, see build_regex_body
    def self.compile_or_nil(pattern, anchor)
      IRegexp.compile(pattern, anchor: anchor)
    rescue IRegexp::Invalid, IRegexp::LimitExceeded
      nil
    end

    # Match, and treat a match that Ruby cannot or will not complete as no match.
    #
    # Deliberate deviation from RFC 9535 sections 2.4.6 and 2.4.7, which say the result is LogicalTrue or
    # LogicalFalse and say nothing about a match that cannot complete: a timeout, or a subject that is
    # not valid UTF-8, gives false. RFC 9485 section 8 (security considerations) is why a timeout exists.
    # @param regexp [Regexp]
    # @param str [String]
    # @return [Boolean]
    def self.match_safely(regexp, str)
      regexp.match?(str)
    rescue IRegexp::TIMEOUT_ERROR, ArgumentError, Encoding::CompatibilityError
      # TIMEOUT_ERROR: the match took longer than IRegexp::MATCH_TIMEOUT.
      # ArgumentError, Encoding::CompatibilityError: str is not valid UTF-8.
      false
    end

    # Metadata + body builder for every built-in JSONPath function.
    #
    #   arity          — number of parameters
    #   literal_return — true when the result is a literal (see RFC 9535
    #                    well-typedness of function extensions)
    #   build          — proc that takes the parsed `parameters` list and
    #                    returns the body proc (parameters allow per-instance
    #                    optimization, e.g. literal-regex compilation)
    REGISTRY = {
      'count' => {
        arity: 1,
        literal_return: true,
        build: ->(_) { ->(nodes) { nodes.is_a?(Array) ? nodes.size : 1 } },
      },
      'length' => {
        arity: 1,
        literal_return: true,
        build: lambda { |_|
          lambda { |value|
            [Array, Hash, String].include?(value.class) ? value.size : :nothing
          }
        },
      },
      'value' => {
        arity: 1,
        literal_return: true,
        build: lambda { |_|
          lambda { |nodes|
            nodes.is_a?(Array) && nodes.size == 1 ? nodes.first : :nothing
          }
        },
      },
      'match' => {
        arity: 2,
        literal_return: false,
        build: ->(parameters) { Functions.build_regex_body(parameters, anchor: true) },
      },
      'search' => {
        arity: 2,
        literal_return: false,
        build: ->(parameters) { Functions.build_regex_body(parameters, anchor: false) },
      },
    }.freeze
  end
end

# Require function parse-method definitions
Dir.children("#{__dir__}/functions/").each do |path|
  require_relative "functions/#{path[0..-4]}"
end
