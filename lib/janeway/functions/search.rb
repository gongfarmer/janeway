# frozen_string_literal: true

module Janeway
  module Functions
    # 2.4.7. search() Function Extension
    # Parameters:
    #   1. ValueType (string)
    #   2. ValueType (string conforming to [RFC9485])
    # Result:
    #     LogicalType
    #
    # The search() function extension provides a way to check whether a given
    # string contains a substring that matches a given regular expression,
    # which is in the form described in [RFC9485].
    #
    # $[?search(@.author, "[BR]ob")]
    #
    # Its arguments are instances of ValueType (possibly taken from a singular
    # query, as for the first argument in the example above). If the first
    # argument is not a string or the second argument is not a string
    # conforming to [RFC9485], the result is LogicalFalse. Otherwise, the
    # string that is the first argument is searched for a substring that
    # matches the I-Regexp contained in the string that is the second argument;
    # the result is LogicalTrue if at least one such substring exists and is
    # LogicalFalse otherwise.
    #
    # tl;dr: How is this different from the match function?
    # "match" must match the entire string, "search" matches a substring.
    def parse_function_search
      consume # function
      raise "expect group_start token, found #{current}" unless current.type == :group_start

      consume # (

      # Read first parameter
      parameters = []
      parameters << parse_function_parameter

      # Consume comma
      if current.type == :union
        consume # ,
      else
        raise "expect comma token, found #{current}" 
      end

      # Read second parameter (the regexp)
      # This could be a string, in which case it is available now.
      # Otherwise it is an expression that takes the regexp from the input document,
      # and the iregexp will not be available until interpretation.
      parameters << parse_function_parameter
      raise "expect group_end token, found #{current}" unless current.type == :group_end

      AST::Function.new('search', parameters) do |str, str_iregexp|
        if str.is_a?(String) && str_iregexp.is_a?(String)
          regexp = translate_iregex_to_ruby_regex(str_iregexp, anchor: false)
          regexp.match?(str)
        else
          false # result defined by RFC9535
        end
      end
    end
  end
end
