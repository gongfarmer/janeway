# frozen_string_literal: true

module Janeway
  # Mixin to provide JSONPath function handlers for Parser
  module Functions
    # The length() function extension provides a way to compute the length of a value
    # and make that available for further processing in the filter expression:
    #
    # JSONPath return type: ValueType
    def parse_function_length
      consume # function
      raise "expect group_start token, found #{current}" unless current.type == :group_start

      consume # (

      # Read parameter
      arg = parse_function_parameter
      parameters = [arg]
      unless arg.singular_query? || arg.literal?
        raise Error, "Invalid parameter - length() expects literal value or singular query, got #{arg.value.inspect}"
      end
      raise err('Too many parameters for length() function call') unless current.type == :group_end

      AST::Function.new('length', parameters)
    end
  end
end
