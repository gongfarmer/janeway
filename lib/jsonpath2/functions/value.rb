# frozen_string_literal: true

module JsonPath2
  module Functions
    #  2.4.8. value() Function Extension

    # Parameters:
    #   1. NodesType
    # Result:
    #   ValueType
    #
    # The value() function extension provides a way to convert an instance of
    # NodesType to a value and make that available for further processing in
    # the filter expression:
    #
    # @example $[?value(@..color) == "red"]
    #
    # Its only argument is an instance of NodesType (possibly taken from a
    # filter-query, as in the example above). The result is an instance of
    # ValueType.
    #
    # If the argument contains a single node, the result is the value of the node.
    #
    # If the argument is the empty nodelist or contains multiple nodes, the result is Nothing.
    #
    # Note: A singular query may be used anywhere where a ValueType is
    # expected, so there is no need to use the value() function extension with a singular query.
    def parse_function_value
      # tl;dr this seems to do the same thing as a name selector? Why does this exist?
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

      AST::Function.new('value', parameters) do |nodes|
        if nodes.is_a?(Array) && nodes.size == 1
          nodes.first
        else
          :nothing
        end
      end
    end
  end
end
