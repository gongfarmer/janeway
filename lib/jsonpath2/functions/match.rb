# frozen_string_literal: true

module JsonPath2
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
    # The regexp dialect is called "I-Regexp" and is defined in RFC9485.
    #
    # Fortunately a shortcut is availalble, that RFC contains instructions
    # for converting an I-Regexp to ruby's regexp format.
    # @see https://www.rfc-editor.org/rfc/rfc9485.html#name-pcre-re2-and-ruby-regexps
    #
    # The instructions are:
    #   * For any unescaped dots (.) outside character classes (first
    #     alternative of charClass production), replace the dot with [^\n\r].
    #   * Enclose the regexp in \A(?: and )\z.
    def parse_function_match
      log "current=#{current}, next_token=#{next_token}"
      consume # function

      # Read parameters
      parameters = []
      raise "expect group_start token, found #{current}" unless current.type == :group_start
      consume # (
      if current.type == :current_node
        parameters << parse_current_node
        consume
      else
        raise "don't know how to evaluate parameter #{current}"
      end
      raise "expect group_end token, found #{current}" unless current.type == :group_end

      AST::Function.new('count', parameters) do |node_list|
        if node_list.is_a?(Array)
          node_list.size
        else
          1
        end
      end
    end
  end
end
