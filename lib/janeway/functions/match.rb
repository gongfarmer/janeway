# frozen_string_literal: true

module Janeway
  # Mixin to provide JSONPath function handlers for Parser
  module Functions
    # The match() function extension provides a way to check whether (the
    # entirety of; see Section 2.4.7) a given string matches a given regular
    # expression, which is in the form described in [RFC9485].
    #
    # @example  $[?match(@.date, "1974-05-..")]
    #
    # Its arguments are instances of ValueType (possibly taken from a
    # singular query, as for the first argument in the example above). If the
    # first argument is not a string or the second argument is not a string
    # conforming to [RFC9485], the result is LogicalFalse. Otherwise, the
    # string that is the first argument is matched against the I-Regexp
    # contained in the string that is the second argument; the result is
    # LogicalTrue if the string matches the I-Regexp and is LogicalFalse
    # otherwise.
    #
    #
    # The pattern is validated and translated by Janeway::IRegexp (RFC 9485). A pattern that is not an
    # I-Regexp gives LogicalFalse (RFC 9535 sections 2.4.6 and 2.4.7). A literal pattern that is over
    # one of the limits in IRegexp (MAX_LENGTH, MAX_REPEAT, MAX_GROUP_DEPTH) raises Janeway::Error when
    # the query is parsed. In a pattern ^ and $ are ordinary characters, as RFC 9485 has no anchors.
    #
    # tl;dr: How is this different from the search function?
    # "match" must match the entire string, "search" matches a substring.
    def parse_function_match
      consume # function
      raise "expect group_start token, found #{current}" unless current.type == :group_start

      consume # (

      # Read first parameter
      parameters = []
      parameters << parse_function_parameter
      raise Error, 'Not enough parameters for match() function call' unless current.type == :union

      consume # ,

      # Read second parameter (the regexp)
      # This could be a string, in which case it is available now.
      # Otherwise it is an expression that takes the regexp from the input document,
      # and the iregexp will not be available until interpretation.
      parameters << parse_function_parameter
      validate_literal_pattern(parameters.last)
      raise Error, 'Too many parameters for match() function call' unless current.type == :group_end

      # Body (including literal-regex fast path) is supplied by
      # Functions::REGISTRY at FunctionInterpreter construction time.
      AST::Function.new('match', parameters)
    end
  end
end
