# frozen_string_literal: true

module Janeway
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
      unless current.type == :group_end
        raise Error, 'Too many parameters for length() function call'
      end

      # Meaning of return value depends on the JSON type:
      #   * string - number of Unicode scalar values in the string.
      #   * array -  number of elements in the array.
      #   * object - number of members in the object.
      # For any other argument value, the result is the special result Nothing.
      AST::Function.new('length', parameters) do |value|
        if [Array, Hash, String].include?(value.class)
          value.size
        else
          :nothing
        end
      end
    end
  end
end
