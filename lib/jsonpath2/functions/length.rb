# frozen_string_literal: true

module JsonPath2
  module Functions
    # The length() function extension provides a way to compute the length of a value
    # and make that available for further processing in the filter expression:
    #
    # JSONPath return type: ValueType
    def parse_function_length
      consume # function
      log "current=#{current}, next_token=#{next_token}"

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
      #consume # )

      # If argument value is a string, result is the number of Unicode scalar values in the string.
      # If argument value is an array, result is the number of elements in the array.
      # If argument value is an object, result is the number of members in the object.
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
