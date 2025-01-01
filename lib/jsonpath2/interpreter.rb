# frozen_string_literal: true

module JsonPath2
  # Tree-walk interpreter to apply the operations from the abstract syntax tree to the input value
  class Interpreter
    attr_reader :query, :output, :env, :call_stack, :unwind_call_stack

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
      unless input.is_a?(Hash) || input.is_a?(Array)
        raise ArgumentError, "expect ruby composite type, got #{input.inspect}"
      end

      @input = input
      @output = []
      @env = {} # execution state
      @call_stack = []
      @unwind_call_stack = -1
    end

    # @param ast [AST::Query] abstract syntax tree
    # @return [Object]
    def interpret(ast)
      raise "expect AST, got #{ast.inspect}" unless ast.is_a?(AST::Query)

      @query = ast

      result = interpret_nodes(@query.expressions)
      result.is_a?(Array) ? result : [result].compact
    end

    private

    attr_writer :unwind_call_stack

    def println(fn_call)
      return false if fn_call.function_name_as_str != 'println'

      result = interpret_node(fn_call.args.first).to_s
      output << result
      true
    end

    # Interpret AST::Root, which returns the input
    def interpret_root(node, _input)
      # Ignore the given _input from the current interpretation state.
      # Root node starts from the top level regardless of current state.
      return @input unless node.value

      # If there is a selector list that modifies this node, then apply it
      case node.value
      when AST::SelectorList then interpret_selector_list(node.value, @input)
      when AST::NameSelector then interpret_name_selector(node.value, @input)
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
      results = selector_list.map { |selector| send(:"interpret_#{selector.type}", selector, input) }

      # FIXME: how to handle a union?
      results = results.first

      # Send result to the next node in the AST, if any
      child = selector_list.child
      return results unless child

      send(:"interpret_#{child.type}", child, results)
    end

    # Filter the input by returning the key that has the given name
    # FIXME: json allows duplicate keys, ruby does not. How to handle this?
    # @param selector [NameSelector]
    def interpret_name_selector(selector, input)
      node = input.respond_to?(:[]) ? input[selector.name] : nil

      return nil if node.nil?
      return node if selector.children.empty?

      # FIXME: can AST::NameSelector have more than one child? If not simplify this
      selector.children.map do |child|
        send(:"interpret_#{child.type}", child, node)
      end
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
    # @return [Array] matching values
    def interpret_wildcard_selector(_selector, input)
      case input
      when Array then input
      when Hash then input.values
      else
        # wildcard selector does not match singular values, only values of composite types
        nil
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

      # Convert -1 placeholder to the actual termination index, for positive step
      last_index =
        if selector.step.positive?
          selector.end == -1 ? (input.size - 1) : selector.end - 1
        else
          selector.end.zero? ? 0 : selector.end + 1
        end

      # Convert -1 placeholder to the actual start index, for negative step
      first_index =
        if selector.step.negative? && selector.start == -1
          input.size - 1
        else
          selector.start
        end

      # Collect values from target indices
      first_index
        .step(to: last_index, by: selector.step)
        .filter_map { |i| input[i] }
    end

    # Return the set of values from the input which for which the filter is true
    # @param selector [AST::FilterSelector]
    # @param input [Hash, Array]
    # @return [nil, Array] list of matched values, or nil if no matched values
    def interpret_filter_selector(selector, input)
      # @see IETF 2.3.5.2
      # filter selector selects nothing when applied to non-composite types.
      return nil unless [Array, Hash].include?(input.class)

      values = input.is_a?(Array) ? input : input.values
      results = values.select { |value| truthy? interpret_node(selector.value, value) }
      results.empty? ? nil : results
    end

    # True if the value is "truthy" in the context of a filter selector.
    #
    # Ruby normally defines truthy as anything besides nil or false.
    # This method also considers empty arrays and arrays containing only nil / false values not to be truthy.
    # Empty Hashes are "truthy", changing that breaks some tests
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
    # @param ds [DescendantSegment]
    # @param input [Object] ruby object to be indexed
    def interpret_descendant_segment(descendant_segment, input)
      visit(input) { |node| interpret_node(descendant_segment.selector, node) }
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
      end
      results.flatten.compact
    end

    def fetch_function_definition(fn_name)
      fn_def = env[fn_name]
      raise JsonPath2::Error::Runtime::UndefinedFunction, fn_name if fn_def.nil?

      fn_def
    end

    def assign_function_args_to_params(stack_frame)
      fn_def = stack_frame.fn_def
      fn_call = stack_frame.fn_call

      given = fn_call.args.length
      expected = fn_def.params.length
      raise JsonPath2::Error::Runtime::WrongNumArg, fn_def.function_name_as_str, given, expected if given != expected

      # Applying the values passed in this particular function call to the respective defined parameters.
      return if fn_def.params.nil?

      fn_def.params.each_with_index do |param, i|
        if env.key?(param.name)
          # A global variable is already defined. We assign the passed in value to it.
          env[param.name] = interpret_node(fn_call.args[i])
        else
          # A global variable with the same name doesn't exist. We create a new local variable.
          stack_frame.env[param.name] = interpret_node(fn_call.args[i])
        end
      end
    end

    def return_detected?(node)
      node.type == 'return'
    end

    def interpret_nodes(nodes)
      last_value = nil

      nodes.each do |node|
        last_value = interpret_node(node, last_value)

        if return_detected?(node)
          raise JsonPath2::Error::Runtime::UnexpectedReturn unless call_stack.length.positive?

          self.unwind_call_stack = call_stack.length # store current stack level to know when to stop returning.
          return last_value
        end

        if unwind_call_stack == call_stack.length
          # We are still inside a function that returned, so we keep on bubbling up
          # from its structures (e.g., conditionals, loops etc).
          return last_value
        elsif unwind_call_stack > call_stack.length
          # We returned from the function, so we reset the "unwind indicator".
          self.unwind_call_stack = -1
        end
      end

      last_value
    end

    # Interpret a node.
    def interpret_node(node, input)
      interpreter_method = "interpret_#{node.type}"
      send(interpreter_method, node, input)
    end

    # Apply selector to each value in the current node and return result
    def interpret_current_node(node, input)
      # If there is a selector list that modifies this node, then apply it
      case node.value
      when AST::SelectorList then interpret_selector_list(node.value, input)
      when AST::NameSelector then interpret_name_selector(node.value, input)
      when AST::WildcardSelector then interpret_wildcard_selector(node.value, input)
      when nil then input
      else
        raise "don't know how to interpret #{node.value.class}"
      end
    end

    def interpret_identifier(identifier)
      if env.key?(identifier.name)
        # Global variable.
        env[identifier.name]
      elsif call_stack.length.postive? && call_stack.last.env.key?(identifier.name)
        # Local variable.
        call_stack.last.env[identifier.name]
      else
        # Undefined variable.
        raise JsonPath2::Error::Runtime::UndefinedVariable, identifier.name
      end
    end

    def interpret_var_binding(var_binding)
      if call_stack.empty?
        # We are inside a function. If the name points to a global var, we assign the value to it.
        # Otherwise, we create and / or assign to a local var.
        if env.key?(var_binding.var_name_as_str)
          env[var_binding.var_name_as_str] = interpret_node(var_binding.right)
        else
          call_stack.last.env[var_binding.var_name_as_str] = interpret_node(var_binding.right)
        end
      else
        # We are not inside a function. Therefore, we create and / or assign to a global var.
        env[var_binding.var_name_as_str] = interpret_node(var_binding.right)
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

    def interpret_repetition(repetition)
      interpret_nodes(repetition.block.expressions) while interpret_node(repetition.condition)
    end

    def interpret_function_definition(fn_def)
      env[fn_def.function_name_as_str] = fn_def
    end

    def interpret_function_call(fn_call)
      return if println(fn_call)

      fn_def = fetch_function_definition(fn_call.function_name_as_str)

      stack_frame = JsonPath2::Runtime::StackFrame.new(fn_def, fn_call)

      assign_function_args_to_params(stack_frame)

      # Executing the function body.
      call_stack << stack_frame
      value = interpret_nodes(fn_def.body.expressions)
      call_stack.pop
      value
    end

    def interpret_return(ret)
      interpret_node(ret.expression)
    end

    # TODO: Is this implementation REALLY the most straightforward in Ruby (apart from using eval)?
    def interpret_unary_operator(unary_op)
      case unary_op.operator
      when :-
        -interpret_node(unary_op.operand)
      else # :'!'
        !interpret_node(unary_op.operand)
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
      lhs && rhs
    end

    def interpret_or(lhs, rhs)
      lhs || rhs
    end

    def interpret_less_than(lhs, rhs)
      lhs < rhs
    rescue
      false
    end

    def interpret_less_than_or_equal(lhs, rhs)
      # Must be done in 2 comparisons, because the equality comparison is
      # valid for many types that do not support the < operator.
      return true if lhs == rhs

      lhs < rhs
    rescue
      # This catches type mismatches like { a: 1 } <= 1
      # IETF says that both < and > return false for such comparisons
      false
    end

    def interpret_greater_than(lhs, rhs)
      lhs > rhs
    rescue
      false
    end

    def interpret_greater_than_or_equal(lhs, rhs)
      return true if lhs == rhs

      lhs > rhs
    rescue
      false
    end

    def interpret_boolean(boolean, _input)
      boolean.value
    end

    def interpret_nil(_nil_node)
      nil
    end

    def interpret_number(number, _input)
      number.value
    end

    def interpret_string_type(string, _input)
      string.value
    end
  end
end
