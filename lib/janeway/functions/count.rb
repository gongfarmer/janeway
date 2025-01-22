# frozen_string_literal: true

module Janeway
  # Mixin to provide JSONPath function handlers for Parser
  module Functions
    # The count() function extension provides a way to obtain the number of
    # nodes in a nodelist and make that available for further processing in
    # the filter expression:
    #
    # Its only argument is a nodelist. The result is a value (an unsigned
    # integer) that gives the number of nodes in the nodelist.
    #
    # Notes:
    #   * There is no deduplication of the nodelist.
    #   * The number of nodes in the nodelist is counted independent of
    #     their values or any children they may have, e.g., the count of a
    #     non-empty singular nodelist such as count(@) is always 1.
    #
    # @example $[?count(@.*.author) >= 5]
    def parse_function_count
      consume # function
      raise "expect group_start token, found #{current}" unless current.type == :group_start

      consume # (

      # Read parameter
      arg = parse_function_parameter
      parameters = [arg]
      raise Error, "Invalid parameter - count() expects node list, got #{arg.value.inspect}" if arg.literal?
      raise Error, 'Too many parameters for count() function call' unless current.type == :group_end

      # Define function body
      AST::Function.new('count', parameters) do |node_list|
        if node_list.is_a?(Array)
          node_list.size
        else
          1 # the count of a non-empty singular nodelist such as count(@) is always 1.
        end
      end
    end
  end
end
