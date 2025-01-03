# frozen_string_literal: true

module JsonPath2
  module Functions
    # The length() function extension provides a way to compute the length of a value
    # and make that available for further processing in the filter expression:
    #
    # JSONPath return type: ValueType
    def parse_function_length
      log "current=#{current}, next_token=#{next_token}"
      consume # function
      raise "expect group_start token, found #{current}" unless current.type == :group_start

      consume # (

      # Read parameter
      parameters = [parse_function_parameter]
      raise "expect group_end token, found #{current}" unless current.type == :group_end

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
