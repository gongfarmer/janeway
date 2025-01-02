# frozen_string_literal: true

module JsonPath2
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
