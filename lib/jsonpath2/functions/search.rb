# frozen_string_literal: true

module JsonPath2
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
      log "current=#{current}, next_token=#{next_token}"
      consume # function

      # Read parameter list
      parameters = []
      raise "expect group_start token, found #{current}" unless current.type == :group_start
      consume # (
      raise "don't know how to evaluate parameter #{current}" unless current.type == :current_node
      # It is possible that 

      # Parse the input argument
      parameters << parse_current_node
      consume
      raise "expect comma token, found #{current}" unless current.type == :union

      consume # ,
      raise "don't know how to evaluate parameter #{current}" unless current.type == :string

      # Parse the regexp string argument, converting it to ruby regexp format
      parameters << translate_iregex_to_ruby_regex(current.literal, anchor: false)
      consume
      raise "expect group_end token, found #{current}" unless current.type == :group_end

      AST::Function.new('search', parameters) do |str, regexp|
        if str.is_a?(String) && regexp.is_a?(Regexp)
          regexp.match?(str)
        else
          false # result defined by RFC9535
        end
      end
    end
  end
end
