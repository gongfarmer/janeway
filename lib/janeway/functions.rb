# frozen_string_literal: true

require_relative 'ast/function'
require_relative 'ast/string_type'

module Janeway
  # Mixin to provide JSONPath function handlers for Parser, plus the shared
  # I-Regexp translation helper and the built-in function registry.
  module Functions
    # Convert IRegexp format to ruby regexp equivalent, following the instructions in rfc9485.
    # @see https://www.rfc-editor.org/rfc/rfc9485.html#name-pcre-re2-and-ruby-regexps
    # @param iregex [String]
    # @param anchor [Boolean] add anchors to match the string start and end
    # @return [Regexp]
    def translate_iregex_to_ruby_regex(iregex, anchor: true)
      # * For any unescaped dots (.) outside character classes (first
      #   alternative of charClass production), replace the dot with [^\n\r].
      chars = iregex.chars
      in_char_class = false
      indexes = []
      chars.each_with_index do |char, i|
        case char
        when '[' then in_char_class = true
        when ']'
          in_char_class = false unless chars[i - 1] == '\\' # escaped ] does not close char class
        when '.'
          next if in_char_class || chars[i - 1] == '\\' # escaped dot

          indexes << i # replace this dot
        end
      end
      indexes.reverse_each do |i|
        chars[i] = '[^\n\r]'
      end

      # * Enclose the regexp in \A(?: and )\z.
      regex_str = anchor ? format('\A(?:%s)\z', chars.join) : chars.join
      Regexp.new(regex_str)
    end
    module_function :translate_iregex_to_ruby_regex

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

    # Build a match/search body. When the pattern is a StringType literal we
    # compile the regex once at parse time (see perf pass, commit fd8b92a).
    # Otherwise fall back to per-call compilation.
    def self.build_regex_body(parameters, anchor:)
      literal_regexp =
        if parameters[1].is_a?(AST::StringType)
          begin
            translate_iregex_to_ruby_regex(parameters[1].value, anchor: anchor)
          rescue RegexpError
            nil # fall back to per-call compilation, which will raise at eval time
          end
        end

      if literal_regexp
        ->(str, _pattern) { str.is_a?(String) && literal_regexp.match?(str) }
      else
        lambda do |str, pattern|
          if str.is_a?(String) && pattern.is_a?(String)
            translate_iregex_to_ruby_regex(pattern, anchor: anchor).match?(str)
          else
            false
          end
        end
      end
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
