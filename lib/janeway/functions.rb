# frozen_string_literal: true

require_relative 'ast/function'

module Janeway
  # Mixin to provide JSONPath function handlers for Parser
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
        # FIXME: does not handle escaped '[', ']', or '.'
        case char
        when '[' then in_char_class = true
        when ']' then in_char_class = false
        when '.'
          next if in_char_class || chars[i-1] == '\\' # escaped dot

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

    # All jsonpath function parameters are one of these accepted types.
    # Parse the function parameter and return the result.
    # @return [String, AST::CurrentNode, AST::RootNode]
    def parse_function_parameter
      result =
        case current.type
        when :string then parse_string
        when :current_node then parse_current_node
        when :root then parse_root
        else
          # Invalid, no function uses this.
          # Instead of crashing here, accept it and let the function return an empty result.
          parse_expr
        end
      consume
      result
    end
  end
end

# Require function definitions
Dir.children("#{__dir__}/functions/").each do |path|
  require_relative "functions/#{path[0..-4]}"
end
