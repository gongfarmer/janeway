# frozen_string_literal: true

require_relative 'parser'

module Janeway
  # Tree-walk interpreter to apply the operations from the abstract syntax tree to the input value
  class Interpreter
    attr_reader :query, :output, :env, :call_stack

    class Error < Janeway::Error; end

    # Specify the parameter types that built-in JsonPath functions require
    FUNCTION_PARAMETER_TYPES = {
      length: [:value_type],
      count: [:nodes_type],
      match: %i[value_type value_type],
      search: %i[value_type value_type],
      value: [:nodes_type],
    }.freeze

    # Functions may accept or return this special value
    NOTHING = :nothing

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
      @query = ast
      raise "expect AST, got #{ast.inspect}" unless ast.is_a?(AST::Query)

      unless @input.is_a?(Hash) || @input.is_a?(Array)
        return [] # can't query on any other types
      end

      interpret_node(ast.root, nil)
    end

    private

    # Interpret AST::RootNode, which refers to the complete original input.
    #
    # Ignore the given _input from the current interpretation state.
    # RootNode starts from the top level regardless of current state.
    # @return [Array]
    def interpret_root_node(node, _input)
      case node&.value
      when AST::ChildSegment then interpret_child_segment(node.value, @input)
      when AST::DescendantSegment then interpret_descendant_segment(node.value, @input)
      when AST::Selector then interpret_selector(node.value, @input)
      when nil then [@input]
      else
        raise "don't know how to interpret #{node.value.class}"
      end
    end

    # Prepare a single node from an input node list to be sent to a selector.
    # (Selectors require a node list as input)
    # Helper method for interpret_child_segment.
    #
    # @param node [Object]
    def as_node_list(node)
      # FIXME: method still used?  Can this be delted?
      result =
        case node
        when Array then node
        when Hash then node
        else [node]
        end
      result
    end

    # Interpret a list of 1 or more selectors, seperated by the union operator.
    #
    # @param child_segment [AST::ChildSegment]
    # @param input [Array, Hash]
    # @return [Array]
    def interpret_child_segment(child_segment, input)
      # For each node in the input nodelist, the resulting nodelist of a child
      # segment is the concatenation of the nodelists from each of its
      # selectors in the order that the selectors appear in the list. Note: Any
      # node matched by more than one selector is kept as many times in the nodelist.
      # combine results from all selectors
      results = nil
      if child_segment.size == 1
        selector = child_segment.first
        results = send(:"interpret_#{selector.type}", selector, input)
      else
        results = []
        child_segment.each do |selector|
          result = send(:"interpret_#{selector.type}", selector, input)
          results.concat(result)
        end
      end


      # Send result to the next node in the AST, if any
      child = child_segment.child
      unless child
        return child_segment.size == 1 ? [results] : results
      end

      send(:"interpret_#{child.type}", child, results)
    end

    # Filter the input by returning the key that has the given name.
    #
    # Must differentiate between a null value of a key that exists (nil)
    # and a key that does not exist ([])
    #
    # @param selector [NameSelector]
    # @return [Array]
    def interpret_name_selector(selector, input)
      return [] unless input.is_a?(Hash) && input.key?(selector.name)

      result = input[selector.name]

      # early exit, no point continuing the chain with no results

      return [result] unless selector.child

      # Interpret child using output of this name selector, and return result
      child = selector.child
      results = send(:"interpret_#{child.type}", child, result)
      results
    end

    # Filter the input by returning the array element with the given index.
    # Return empty list if input is not an array, or if array does not contain index.
    #
    # Output is an array because all selectors must return node lists, even if
    # they only select a single element.
    #
    # @param selector [IndexSelector]
    # @param input [Array]
    # @return [Array]
    def interpret_index_selector(selector, input)
      return [] unless input.is_a?(Array)

      result = input.fetch(selector.value) # raises IndexError if no such index

      # Interpret child using output of this name selector, and return result
      child = selector.child
      return [result] unless child

      results = send(:"interpret_#{child.type}", child, result)
      results
    rescue IndexError
      [] # returns empty array if no such index
    end

    # Return values from the input.
    # For array, return the array.
    # For Hash, return hash values.
    # For anything else, return empty list.
    #
    # @param selector [AST::WildcardSelector]
    # @param input [Object] usually Array or Hash
    # @return [Array] matching values
    def interpret_wildcard_selector(selector, input)
      values =
        case input
        when Array then input
        when Hash then input.values
        else []
        end

      return values if values.empty? # early exit, no need for further processing on empty list
      return values unless selector.child

      # Apply next selector to every value
      # FIXME: is this correct??  Makes the CTS pass  "basic, wildcard shorthand, then name shorthand"
      child = selector.child
      results = []
      values.each do |value|
        result = send(:"interpret_#{child.type}", child, value)
        results << result.first unless result.empty?
      end
      results
    end

    # Filter the input by applying the array slice selector.
    # Returns at most 1 element.
    #
    # @param selector [ArraySliceSelector]
    # @param input [Array]
    # @return [Array]
    def interpret_array_slice_selector(selector, input)
      return [] unless input.is_a?(Array)
      return [] if selector.step && selector.step.zero? # IETF: When step is 0, no elements are selected.

      # Calculate the upper and lower indices of the target range
      lower = selector.lower_index(input.size)
      upper = selector.upper_index(input.size)

      # Collect values from target indices. Omit the value from the final index.
      results =
        if selector.step.positive?
          lower.step(to: upper - 1, by: selector.step).map { input[_1] }
        else
          upper.step(to: lower + 1, by: selector.step).map { input[_1] }
        end

      # Interpret child using output of this name selector, and return result
      child = selector.child
      return results unless child

      send(:"interpret_#{child.type}", child, results)
    end

    # Return the set of values from the input for which the filter is true.
    # For array, acts on array values.
    # For hash, acts on hash values.
    # Otherwise returns empty node list.
    #
    # @param selector [AST::FilterSelector]
    # @param input [Object]
    # @return [Array] list of matched values, or nil if no matched values
    def interpret_filter_selector(selector, input)
      values =
        case input
        when Array then input
        when Hash then input.values
        else return [] # early exit
        end

      results = []
      values.each do |value|
        # Run filter and interpret result
        result = interpret_node(selector.value, value)

        case result
        when TrueClass then results << value # comparison test - pass
        when FalseClass then nil # comparison test - fail
        when Array then results << value unless result.empty? # existence test - node list
        else
          results << value # existence test. Null values here == success.
        end
      end

      return results unless selector.child

      # Interpret child using output of this name selector, and return result
      child = selector.child
      send(:"interpret_#{child.type}", child, results)
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
    # @param input [Object]
    # @return [Array<AST::Expression>] node list
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

    # Interpret an AST node.
    # Return the result, which may be a node list or basic type.
    # @return [Object]
    def interpret_node(node, input)
      interpreter_method = "interpret_#{node.type}"
      send(interpreter_method, node, input)
    end

    # Interpret a node and extract its value, in preparation for using the node
    # in a comparison operator.
    # Basic literals such as AST::Number and AST::StringType evaluate to a number or string,
    # but selectors and segments evaluate to a node list.  Extract the value (if any)
    # from the node list, or return basic type.
    #
    # @param node [AST::Expression]
    # @param input [Object]
    def interpret_node_as_value(node, input)

      # nodes must be singular queries or literals
      case node
      when AST::CurrentNode, AST::RootNode
        raise Error, "Expression #{node} does not produce a singular value for comparison" unless node.singular_query?
      when AST::Number, AST::StringType, AST::Null, AST::Function, AST::Boolean then nil
      else
        raise "Invalid expression for comparison: #{node}"
      end

      result = interpret_node(node, input)

      # Return basic types (ie. from AST::Number, AST::StringType)
      return result unless result.is_a?(Array)

      # Node lists are returned by Selectors, ChildSegment, DescendantSegment.
      #
      # This is for a comparison operator.
      # An empty node list represents a missing element.
      # This must not match any literal value (including null /nil) but must match another missing value.
      return result if result.empty?

      # Return the only node in the node list
      raise 'node list contains multiple elements but this is a comparison' unless result.size == 1

      result.first
    end

    # Given the result of evaluating an expression which is presumed to be a node list,
    # convert the result into a basic ruby value (ie. Integer, String, nil)
    # @param node_list [Array]
    # @return [String, Integer, Float, nil]
    def node_result_to_value(node_list)
      return nil if node_list.empty?

      return node_list.first if node_list.size == 1

      raise "don't know how to handle node list with size > 1: #{node_list.inspect}"
    end

    # Evaluate a selector and return the result
    # @return [Array] node list containing evaluation result
    def interpret_selector(selector, input)
      case selector
      when AST::NameSelector then interpret_name_selector(selector, input)
      when AST::WildcardSelector then interpret_wildcard_selector(selector, input)
      when AST::IndexSelector then interpret_index_selector(selector, input)
      when AST::ArraySliceSelector then interpret_array_slice_selector(selector, input)
      when AST::FilterSelector then interpret_filter_selector(selector, input)
      else
        raise "Not a selector: #{selector.inspect}"
      end
    end

    # Apply selector to each value in the current node and return result.
    #
    # The result is an Array containing all results of evaluating the CurrentNode's selector (if any.)
    #
    # If the selector extracted values from nodes such as strings, numbers or nil/null, these will be included in the array.
    # If the selector did not match any node, the array may be empty.
    # If there was no selector, then the current input node is returned in the array.
    #
    # @param current_node [CurrentNode] current node identifer
    # @param input [Hash, Array]
    # @return [Array] Node List containing all results from evaluating this node's selectors.
    def interpret_current_node(current_node, input)
      next_expr = current_node.value
      result =
        # All of these return a node list
        case next_expr
        when AST::NameSelector then interpret_name_selector(next_expr, input)
        when AST::WildcardSelector then interpret_wildcard_selector(next_expr, input)
        when AST::IndexSelector then interpret_index_selector(next_expr, input)
        when AST::ArraySliceSelector then interpret_array_slice_selector(next_expr, input)
        when AST::FilterSelector then interpret_filter_selector(next_expr, input)
        when AST::ChildSegment then interpret_child_segment(next_expr, input)
        when AST::DescendantSegment then interpret_descendant_segment(next_expr, input)
        when NilClass then input # FIXME: put it in a node list???
        else
          raise "don't know how to interpret #{next_expr}"
        end
      result
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
        raise Janeway::Error::Runtime::UndefinedVariable, identifier.name
      end
    end

    # The binary operators are all comparison operators that test equality.
    #
    #  * boolean values specified in the query
    #  * JSONPath expressions which must be evaluated
    #
    # After a JSONPath expression is evaluated, it results in a node list.
    # This may contain literal values or nodes, whose value must be extracted before comparison.
    #
    # @return [Boolean]
    def interpret_binary_operator(binary_op, input)
      case binary_op.operator
      when :and, :or
        # handle node list for existence check
        lhs = interpret_node(binary_op.left, input)
        rhs = interpret_node(binary_op.right, input)
      when :equal, :not_equal, :less_than, :greater_than, :less_than_or_equal, :greater_than_or_equal
        # handle node values for comparison check
        lhs = interpret_node_as_value(binary_op.left, input)
        rhs = interpret_node_as_value(binary_op.right, input)
      else
        raise "don't know how to handle binary operator #{binary_op.inspect}"
      end
      send(:"interpret_#{binary_op.operator}", lhs, rhs)
    end

    def interpret_equal(lhs, rhs)

      # When either side of a comparison results in an empty nodelist or the
      # special result Nothing (see Section 2.4.1):
      # A comparison using the operator == yields true if and only if the other
      # side also results in an empty nodelist or the special result Nothing.
      lhs = NOTHING if lhs == []
      rhs = NOTHING if rhs == []

      lhs == rhs
    end

    def interpret_not_equal(lhs, rhs)
      !interpret_equal(lhs, rhs)
    end

    # Interpret && operator
    # May receive node lists, in which case empty node list == false
    def interpret_and(lhs, rhs)
      # non-empty array is already truthy, so that works properly without conversion
      lhs = false if lhs == []
      rhs = false if rhs == []
      lhs && rhs
    end

    # Interpret || operator
    # May receive node lists, in which case empty node list == false
    def interpret_or(lhs, rhs)
      # non-empty array is already truthy, so that works properly without conversion
      lhs = false if lhs.is_a?(Array) && lhs.empty?
      rhs = false if rhs.is_a?(Array) && rhs.empty?
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
      return true if interpret_equal(lhs, rhs)

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
      return true if interpret_equal(lhs, rhs)

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

    # @param _null [AST::Null] ignored
    # @param _input [Object] ignored
    def interpret_null(_null, _input)
      nil
    end

    # FIXME: split implementation out into separate methods for not and minus
    # because they are so different.
    def interpret_unary_operator(op, input)
      node_list = send(:"interpret_#{op.operand.type}", op.operand, input)
      case op.operator
      when :not then interpret_not(node_list)
      when :minus then 0 - node_list.first # FIXME: sure hope this is a number!
      else raise "unknown unary operator #{op.inspect}"
      end
    end

    # Interpret unary operator "!".
    # For a node list, this is an existence check that just determines if the list is empty.
    # For a boolean, this inverts the meaning of the input.
    # @return [Boolean]
    def interpret_not(input)
      result =
        case input
        when Array then input.empty?
        when TrueClass, FalseClass then !input
        else
          raise "don't know how to apply not operator to #{input.inspect}"
        end
      result
    end

    # @param function [AST::Function]
    # @param input [Hash, Array]
    def interpret_function(function, input)
      params = evaluate_function_parameters(function.parameters, function.name, input)
      result = function.body.call(*params)
      result
    end

    # Evaluate the expressions in the parameter list to make the parameter values
    # to pass in to a JsonPath function.
    #
    # The node lists returned by a singular query must be deconstructed into a single value for
    # parameters of ValueType, this is done here.
    # For explanation:
    # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-well-typedness-of-function-
    #
    # @param parameters [Array] parameters before evaluation
    # @param func [String] function name (eg. "length", "count")
    # @param input [Object]
    # @return [Array] parameters after evaluation
    def evaluate_function_parameters(parameters, func, input)
      param_types = FUNCTION_PARAMETER_TYPES[func.to_sym]

      parameters.map.with_index do |parameter, i|
        type = param_types[i]
        case parameter
        when AST::CurrentNode, AST::RootNode
          # Selectors always return a node list.
          # Deconstruct the resulting node list if function parameter type is ValueType.
          result = interpret_node(parameter, input)
          if type == :value_type && parameter.singular_query?
            deconstruct(result)
          else
            result
          end
        when AST::StringType, AST::Number
          interpret_string_type(parameter, input)
        else
          # invalid parameter type. Function must accept it and return Nothing result
          parameter
        end
      end
    end

    # Prepare a value to be passed to as a parameter with type ValueType.
    # Singular queries (see RFC) produce a node list containing one value.
    # Return the value.
    #
    # Implements this part of the RFC:
    #   > When the declared type of the parameter is ValueType and
    #     the argument is one of the following:
    #   > ...
    #   >
    #   > A singular query. In this case:
    #   > * If the query results in a nodelist consisting of a single node,
    #       the argument is the value of the node.
    #   > * If the query results in an empty nodelist, the argument is
    #       the special result Nothing.
    #
    # @param input [Object] usually an array - sometimes a basic type like String, Numeric
    # @return [Object] basic type -- string or number
    def deconstruct(input)
      return input unless input.is_a?(Array)

      if input.size == 1
        # FIXME: what if it was a size 1 array that was intended to be a node not a node list? How to detect this?
        input.first
      elsif input.empty?
        NOTHING
      else
        input # input is a single node, which happens to be an Array
      end
    end
  end
end
