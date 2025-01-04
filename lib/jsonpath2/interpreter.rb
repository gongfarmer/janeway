# frozen_string_literal: true

module JsonPath2
  # Tree-walk interpreter to apply the operations from the abstract syntax tree to the input value
  class Interpreter
    attr_reader :query, :output, :env, :call_stack

    # Interpret a query on the given input, return result
    # @param input [Hash, Array]
    # @param query [String]
    def self.interpret(input, query)
      raise ArgumentError, "expect query string, got #{query.inspect}" unless query.is_a?(String)

      tokens = Lexer.lex(query)
      ast = Parser.new(tokens).parse
      new(input).interpret(ast)
    end

    # @param input [Array,Hash] tree of data which the jsonpath query is addressing
    def initialize(input)
      @input = input
    end

    # @param ast [AST::Query] abstract syntax tree
    # @return [Object]
    def interpret(ast)
      raise "expect AST, got #{ast.inspect}" unless ast.is_a?(AST::Query)
      unless @input.is_a?(Hash) || @input.is_a?(Array)
        return [] # can't query on any other types
      end

      @query = ast

      result = interpret_nodes(@query.expressions)
      case result
      when Array then result.reject { _1 == :none }
      when :none then []
      else [result].compact
      end
    end

    private

    # Interpret AST::Root, which returns the input
    def interpret_root(node, _input)
      # Ignore the given _input from the current interpretation state.
      # Root node starts from the top level regardless of current state.
      return [@input] unless node.value

      # If there is a selector list that modifies this node, then apply it
      case node.value
      when AST::SelectorList then interpret_selector_list(node.value, @input)
      when AST::NameSelector then interpret_name_selector(node.value, @input)
      when AST::DescendantSegment then interpret_descendant_segment(node.value, @input)
      when AST::WildcardSelector then interpret_wildcard_selector(node.value, @input)
      else
        raise "don't know how to interpret #{node.value.class}"
      end
    end

    # Interpret a list of 1 or more selectors, seperated by the union operator.
    #
    # @param selector_list[AST::SelectorList]
    # @param input [Array, Hash] data which the jsonpath query is addressing
    # @return [Array] results
    def interpret_selector_list(selector_list, input)
      # This is a list of multiple selectors.
      # Evaluate each one against the same input, and combine the results.
      results = selector_list
        .map { |selector| send(:"interpret_#{selector.type}", selector, input) }
        .reject { _1 == [] }

      # combine results
      result =
        if selector_list.size > 1
          results.flatten(1).compact
        else
          results.empty? ? :none : results.first
        end

      # Send result to the next node in the AST, if any
      child = selector_list.child
      return result unless child

      send(:"interpret_#{child.type}", child, result)
    end

    # Filter the input by returning the key that has the given name.
    #
    # Must differentiate between a null value of a key that exists (nil)
    # and a key that does not exist (:none)
    #
    # @param selector [NameSelector]
    def interpret_name_selector(selector, input)
      return :none unless input.is_a?(Hash)

      # Determine whether key exists, get key value which may be nil
      if input.key?(selector.name)
        node = input[selector.name] # possibly nil
      else
        return :none
      end
      return node unless selector.child

      # Interpret child using output of this name selector, and return result
      child = selector.child
      send(:"interpret_#{child.type}", child, node)
    end

    # Filter the input by returning the array element with the given index.
    # Return nil if input is not an array.
    # @param selector [IndexSelector]
    def interpret_index_selector(selector, input)
      return nil unless input.is_a?(Array)

      input[selector.value]
    end

    # "Filter" the input by returning values, but not keys.
    #
    # @param selector [WildcardSelector]
    # @param input [Hash, Array]
    # @return [Array, nil] matching values (nil if input is not a composite type)
    def interpret_wildcard_selector(selector, input)
      result =
        case input
        when Array then input
        when Hash then input.values
        else return :none # early exit -- no need to interpret child for this result
        end
      return result unless selector.child

      # Interpret child using output from this selector, and return result
      child = selector.child
      result.filter_map do |value|
        send(:"interpret_#{child.type}", child, value)
      end
    end

    # Filter the input by applying the array slice selector.
    # Returns at most 1 element.
    #
    # @param selector [ArraySliceSelector]
    # @return [Object, nil] nil if index does not match anything
    def interpret_array_slice_selector(selector, input)
      return nil unless input.is_a?(Array)
      return nil if selector.step.zero? # IETF: When step is 0, no elements are selected.

      # Convert -1 placeholder to the last index, for positive step
      last_index =
        if selector.step.positive?
          selector.end == -1 ? (input.size - 1) : selector.end - 1
        else
          selector.end.zero? ? 0 : selector.end + 1
        end

      # Convert -1 placeholder to the first index, for negative step
      first_index =
        if selector.step.negative? && selector.start == -1
          input.size - 1
        else
          selector.start
        end

      # Put bounds on integer indices. There's no reason to check a million indices for small array.
      first_index = first_index.clamp(0, input.size)
      last_index = last_index.clamp(0, input.size)

      # Collect values from target indices.
      results = []
      first_index
        .step(to: last_index, by: selector.step)
        .each { |i| results << input[i] } # Enumerator::ArithmeticSequence has no #map, must use #each
      results.compact!
      results
    end

    # Return the set of values from the input for which the filter is true
    # @param selector [AST::FilterSelector]
    # @param input [Hash, Array]
    # @return [nil, Array] list of matched values, or nil if no matched values
    def interpret_filter_selector(selector, input)
      # @see IETF 2.3.5.2, filter selector selects nothing when applied to non-composite types.
      return :none unless [Array, Hash].include?(input.class)

      values = input.is_a?(Array) ? input : input.values

      # Current_node operator: just do existence check. Nil values are retained.
      if selector.value.is_a?(AST::CurrentNode)
        #return values.map { |value| interpret_node(selector.value, value) }
        return values.select do |value|
          result = interpret_node(selector.value, value)
          result != :none
        end
      end

      # Comparison operator: discard values with non-truthy result
      #results = values.select { |value| truthy? interpret_node(selector.value, value) }
      results = values.select do |value|
        result = interpret_node(selector.value, value)
        result != :none && result != false
      end
      results.empty? ? nil : results
    end

    # FIXME: no longer used - delete?
    # True if the value is "truthy" in the context of a filter selector.
    #
    # Ruby normally defines truthy as anything besides nil or false.
    # JsonPath also considers empty arrays and arrays containing only nil / false values not to be truthy.
    #
    # Empty Hashes are still "truthy", changing that breaks some tests.
    #
    # @return [Boolean]
    def truthy?(value)
      case value
      when Array then value.any? # false for empty array or array that contains only nil / false values
      else
        !!value
      end
    end

    # Combine results from selectors into a single list.
    # Duplicate elements are allowed.
    #
    # @param lhs [Array] left hand side
    # @param rhs [Array] right hand side
    # @return [Array]
    def interpret_union(lhs, rhs)
      if lhs.is_a?(Array) && rhs.is_a?(Array)
        # can't use ruby's array union operator "|" here because it eliminates duplicates
        lhs.concat rhs
      else
        [lhs, rhs]
      end
    end

    # Find all descendants of the current input that match the selector in the DescendantSegment
    #
    # @param descendant_segment [DescendantSegment]
    # @param input [Object] ruby object to be indexed
    def interpret_descendant_segment(descendant_segment, input)
      results = visit(input) { |node| interpret_node(descendant_segment.selector, node) }

      return results unless descendant_segment.child

      child = descendant_segment.child
      send(:"interpret_#{child.type}", child, results)
    end

    # Visit all descendants of `root`.
    # Return results of applying `action` on each.
    def visit(root, &action)
      results = [yield(root)]

      case root
      when Array
        results.concat(root.map { |elt| visit(elt, &action) })
      when Hash
        results.concat(root.values.map { |value| visit(value, &action) })
      else
        root
      end

      results.flatten(1).compact
    end

    def interpret_nodes(nodes)
      last_value = nil

      nodes.each do |node|
        last_value = interpret_node(node, last_value)
      end

      last_value
    end

    # Interpret a node.
    def interpret_node(node, input)
      interpreter_method = "interpret_#{node.type}"
      send(interpreter_method, node, input)
    end

    # Apply selector to each value in the current node and return result
    # @param node [CurrentNode] current node identifer, "@"
    # @param input [Hash, Array]
    def interpret_current_node(node, input)
      # If there is a selector list that modifies this node, then apply it
      case node.value
      when AST::SelectorList then interpret_selector_list(node.value, input)
      when AST::NameSelector then interpret_name_selector(node.value, input)
      when AST::WildcardSelector then interpret_wildcard_selector(node.value, input)
      when AST::DescendantSegment then interpret_descendant_segment(node.value, input)
      when nil then input
      else
        raise "don't know how to interpret #{node.value.class}"
      end
    end

    def interpret_identifier(identifier, _input)
      if env.key?(identifier.name)
        # Global variable.
        env[identifier.name]
      elsif call_stack.length.positive? && call_stack.last.env.key?(identifier.name)
        # Local variable.
        call_stack.last.env[identifier.name]
      else
        # Undefined variable.
        raise JsonPath2::Error::Runtime::UndefinedVariable, identifier.name
      end
    end

    # TODO: Empty blocks are accepted both for the IF and for the ELSE.
    # For the IF, the parser returns a block with an empty collection of expressions.
    # For the else, no block is constructed.
    # The evaluation is already resulting in nil, which is the desired behavior.
    # It would be better, however, if the parser also returned a block with no expressions
    # for an ELSE with an empty block, as is the case in an IF with an empty block.
    # Investigate this nuance of the parser in the future.
    def interpret_conditional(conditional)
      evaluated_cond = interpret_node(conditional.condition)

      # We could implement the line below in a shorter way, but better to be explicit about truthiness in JsonPath2.
      if [nil, false].include?(evaluated_cond)
        return nil if conditional.when_false.nil?

        interpret_nodes(conditional.when_false.expressions)
      else
        interpret_nodes(conditional.when_true.expressions)
      end
    end

    def interpret_binary_operator(binary_op, input)
      lhs = interpret_node(binary_op.left, input)
      rhs = interpret_node(binary_op.right, input)
      send(:"interpret_#{binary_op.operator}", lhs, rhs)
    end

    def interpret_equal(lhs, rhs)
      lhs == rhs
    end

    def interpret_not_equal(lhs, rhs)
      lhs != rhs
    end

    def interpret_and(lhs, rhs)
      # :none is false within a logical operator
      lhs = lhs == :none ? false : lhs
      rhs = rhs == :none ? false : rhs
      lhs && rhs
    end

    def interpret_or(lhs, rhs)
      # :none is false within a logical operator
      lhs = lhs == :none ? false : lhs
      rhs = rhs == :none ? false : rhs
      lhs || rhs
    end

    def interpret_less_than(lhs, rhs)
      lhs < rhs
    rescue StandardError
      false
    end

    def interpret_less_than_or_equal(lhs, rhs)
      # Must be done in 2 comparisons, because the equality comparison is
      # valid for many types that do not support the < operator.
      return true if lhs == rhs

      lhs < rhs
    rescue StandardError
      # This catches type mismatches like { a: 1 } <= 1
      # IETF says that both < and > return false for such comparisons
      false
    end

    def interpret_greater_than(lhs, rhs)
      lhs > rhs
    rescue StandardError
      false
    end

    def interpret_greater_than_or_equal(lhs, rhs)
      return true if lhs == rhs

      lhs > rhs
    rescue StandardError
      false
    end

    # @param boolean [AST::Boolean]
    # @return [Boolean]
    def interpret_boolean(boolean, _input)
      boolean.value
    end

    # @param number [AST::Number]
    # @return [Integer, Float]
    def interpret_number(number, _input)
      number.value
    end

    # @param string [AST::StringType]
    # @return [String]
    def interpret_string_type(string, _input)
      string.value
    end

    # @param null [AST::Null]
    def interpret_null(_null, _input)
      nil
    end

    def interpret_unary_operator(op, input)
      result = send(:"interpret_#{op.operand.type}", op.operand, input)
      case op.operator
      when :not then !result
      when :minus then 0 - result
      else raise "unknown unary operator #{op.inspect}"
      end
    end

    # @param function [AST::Function]
    # @param input [Hash, Array]
    def interpret_function(function, input)
      params = evaluate_function_parameters(function.parameters, input)
      function.body.call(*params)
    end

    # All jsonpath functions accept 1 or 2 parameters:
    # 1. Expression that evaluates to a node list 
    # 2. (Optional) regexp
    #
    # Parameter 2 may be expressed as a string, or as an expression that takes a
    # string from the input document.
    #
    # @param parameters [Array] parameters before evaluation
    # @return [Array] parameters after evaluation
    def evaluate_function_parameters(parameters, input)
      parameters.map do |parameter|
        case parameter
        when AST::CurrentNode then interpret_current_node(parameter, input)
        when AST::Root then interpret_root(parameter, input)
        when AST::StringType then interpret_string_type(parameter, input)
        else
          # invalid parameter type. Function must accept it and return Nothing result
          parameter
        end
      end
    end
  end
end
