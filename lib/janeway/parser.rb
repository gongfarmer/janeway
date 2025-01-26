# frozen_string_literal: true

require_relative 'error'
require_relative 'functions'
require_relative 'lexer'

module Janeway
  # Transform a list of tokens into an Abstract Syntax Tree
  class Parser
    attr_reader :tokens

    include Functions

    UNARY_OPERATORS = %w[! -].freeze
    BINARY_OPERATORS = %w[== != > < >= <= ,].freeze
    LOGICAL_OPERATORS = %w[&& ||].freeze
    LOWEST_PRECEDENCE = 0
    OPERATOR_PRECEDENCE = {
      ',' => 0,
      '||' => 1,
      '&&' => 2,
      '==' => 3,
      '!=' => 3,
      '>' => 4,
      '<' => 4,
      '>=' => 4,
      '<=' => 4,
      '(' => 8,
    }.freeze

    # @param jsonpath [String] jsonpath query to be lexed and parsed
    # @return [Query]
    def self.parse(jsonpath)
      raise ArgumentError, "expect jsonpath string, got #{jsonpath.inspect}" unless jsonpath.is_a?(String)

      tokens = Janeway::Lexer.lex(jsonpath)
      new(tokens, jsonpath).parse
    end

    # @param tokens [Array<Token>]
    # @param jsonpath [String] original jsonpath query string
    def initialize(tokens, jsonpath)
      @tokens = tokens
      @next_p = 0
      @jsonpath = jsonpath
    end

    # Parse the token list and create an Abstract Syntax Tree
    # @return [Query]
    def parse
      consume
      raise err('JsonPath queries must start with root identifier "$"') unless current.type == :root

      root_node = parse_root
      consume
      unless current.type == :eof
        remaining = tokens[@next_p..].map(&:lexeme).join
        raise err("Unrecognized expressions after query: #{remaining}")
      end

      Query.new(root_node, @jsonpath)
    end

    private

    def pending_tokens?
      @next_p < tokens.length
    end

    def next_not_terminator?
      next_token && next_token.type != :"\n" && next_token.type != :eof
    end

    # Make "next" token become "current" by moving the pointer
    # @return [Token] consumed token
    def consume(offset = 1)
      t = lookahead(offset)
      @next_p += offset
      t
    end

    # Return literal of current token. Consume.
    # @return [String, Integer] literal value of token that is `current` when function is called.
    def current_literal_and_consume
      current.literal.tap { consume }
    end

    def consume_if_next_is(token_type)
      if next_token.type == token_type
        consume
        true
      else
        unexpected_token_error(token_type)
        false
      end
    end

    def previous
      lookahead(-1)
    end

    def current
      lookahead(0)
    end

    def next_token
      lookahead
    end

    def lookahead(offset = 1)
      lookahead_p = (@next_p - 1) + offset
      return nil if lookahead_p.negative? || lookahead_p >= tokens.length

      tokens[lookahead_p]
    end

    def current_precedence
      OPERATOR_PRECEDENCE[current.lexeme] || LOWEST_PRECEDENCE
    end

    def next_precedence
      OPERATOR_PRECEDENCE[next_token.lexeme] || LOWEST_PRECEDENCE
    end

    def unexpected_token_error(expected_type = nil)
      if expected_type
        raise err(
          "Unexpected token #{current.lexeme.inspect} " \
          "(expected #{expected_type}, got #{next_token.lexeme} )"
        )
      end
      raise err("Unexpected token #{current.lexeme.inspect} (next is #{next_token})")
    end

    def determine_parsing_function
      parse_methods = %I[identifier number string true false nil function if while root current_node]
      if parse_methods.include?(current.type)
        :"parse_#{current.type}"
      elsif current.type == :group_start # (
        :parse_grouped_expr
      elsif %I[\n eof].include?(current.type)
        :parse_terminator
      elsif UNARY_OPERATORS.include?(current.lexeme)
        :parse_unary_operator
      elsif current.type == :child_start # [
        :parse_child_segment
      elsif current.type == :dot # .
        :parse_dot_notation
      elsif current.type == :descendants # ..
        :parse_descendant_segment
      elsif current.type == :filter # ?
        :parse_filter_selector
      elsif current.type == :null # null
        :parse_null
      else
        raise err("Don't know how to parse #{current}")
      end
    end

    # @return [nil, Symbol]
    def determine_infix_function(token = current)
      return unless (BINARY_OPERATORS + LOGICAL_OPERATORS).include?(token.lexeme)

      :parse_binary_operator
    end

    # A non-delimited word that is not a keyword within a jsonpath query is not allowed.
    # eg. $[?@==foo]
    # @raise
    def parse_identifier
      unexpected_token_error
    end

    def parse_string
      AST::StringType.new(current.literal)
    end

    def parse_number
      AST::Number.new(current.literal)
    end

    # Consume minus operator and apply it to the (expected) number token following it.
    # Don't consume the number token. The minus operator does not end up in the AST.
    def parse_minus_operator
      raise err("Expect token '-', got #{current.lexeme.inspect}") unless current.type == :minus

      # RFC: negative 0 is allowed within a filter selector comparison, but is NOT allowed
      #      within an index selector or array slice selector.
      # Detect that condition here
      if next_token.type == :number && next_token.literal.zero?
        if [previous.type, lookahead(2).type].any? { _1 == :array_slice_separator }
          raise err('Negative zero is not allowed in an array slice selector')
        elsif %i[union child_start].include?(previous.type)
          raise err('Negative zero is not allowed in an index selector')
        end
      end

      # '-' must be followed by a number token.
      # Parse number and apply - sign to its literal value
      consume
      parse_number
      unless current.literal.is_a?(Numeric)
        raise err("Minus operator \"-\" must be followed by number, got #{current.lexeme.inspect}")
      end

      current.literal *= -1
      current
    end

    # @return [AST::Null]
    def parse_null
      AST::Null.new
    end

    # @return [AST::Boolean]
    def parse_boolean
      AST::Boolean.new(current.literal == 'true')
    end

    # Parse a descendant segment.
    #
    # The descendant segment consists of a double dot "..", followed by
    # a child segment (using bracket notation).
    #
    #  Shorthand notations are also provided that correspond to the shorthand forms of the child segment.
    #
    #    descendant-segment  = ".." (bracketed-selection /
    #                                wildcard-selector /
    #                                member-name-shorthand)
    #  ..*, the descendant-segment directly built from a
    #  wildcard-selector, is shorthand for ..[*].
    #
    #  ..<member-name>, a descendant-segment built from a
    #  member-name-shorthand, is shorthand for ..['<member-name>'].
    #  Note: as with the similar shorthand of a child-segment, this can
    #  only be used with member names that are composed of certain
    #  characters, as specified in the ABNF rule member-name-shorthand.
    #
    #  Note: .. on its own is not a valid segment.
    def parse_descendant_segment
      consume # '..'

      selector =
        case next_token.type
        when :wildcard then parse_wildcard_selector
        when :child_start then parse_child_segment
        when :string, :identifier then parse_name_selector
        else
          msg = 'Descendant segment ".." must be followed by selector'
          msg += ", got ..#{next_token.type}" unless next_token.type == :eof
          raise err(msg)
        end

      AST::DescendantSegment.new.tap do |ds|
        # If there is another selector after this one, make it a child
        ds.next = selector
      end
    end

    # Dot notation represents a name selector, and is an alternative to bracket notation.
    # These examples are equivalent:
    #   $.store
    #   $[store]
    #
    # RFC9535 grammar specifies that the dot may be followed by only 2 selector types:
    #   * WildCardSelector ("*")
    #   * member name (with only certain chars useable. For example, names containing dots are not allowed here.)
    def parse_dot_notation
      consume # "."
      unless current.type == :dot
        # Parse error. Determine the most useful error message for this situation:
        msg =
          if current.type == :number
            "Decimal point must be preceded by number, got \".#{current.lexeme}\""
          else
            'Dot "." begins a name selector, and must be followed by an ' \
              "object member name, #{next_token.lexeme.inspect} is invalid here"
          end
        raise err(msg)
      end

      case next_token.type
      when :identifier then parse_name_selector
      when :wildcard then parse_wildcard_selector
      else
        raise err(
          'Dot "." begins a name selector, and must be followed by an ' \
          "object member name, #{next_token.lexeme.inspect} is invalid here"
        )
      end
    end

    def parse_grouped_expr
      consume

      expr = parse_expr_recursively
      return unless consume_if_next_is(:group_end)

      expr
    end

    def parse_terminator
      nil
    end

    # Parse the root identifier "$", and any subsequent selector
    # @return [AST::RootNode]
    def parse_root
      AST::RootNode.new.tap do |root_node|
        root_node.next = parse_next_selector
      end
    end

    # Parse the current node operator "@", and any subsequent selector
    # @return [AST::CurrentNode]
    def parse_current_node
      AST::CurrentNode.new.tap do |current_node|
        current_node.next = parse_next_selector
      end
    end

    # Parse one or more selectors surrounded by parentheses.
    #
    # More than 1 selector may be within the parentheses, as long as they are separated by commas.
    # If multiple selectors are given, then their results will be combined during the
    # interpretation stage.
    #
    # The selectors may be any of these types:
    #   * name selector, eg. 'name', selects a named child of an object.
    #   * index selector, eg. 3, selects an indexed child of an array.
    #   * wildcard selector, eg. * selects all children of a node and in the expression ..[*]
    #     selects all descendants of a node.
    #   * array slice selector selects a series of elements from an array, giving a start position,
    #     an end position, and an optional step value that moves the position from the start to the end.
    #   * filter expressions select certain children of an object or array, as in:
    #
    # When there is only a single selector in the list, parse and return that selector only.
    # When there are multiple selectors, create a ChildSegment that contains all the selectors.
    #
    # This is not just a speed optimization. Serial selectors that feed into
    # each other have different behaviour than serial child segments.
    #
    # @return [AST::ChildSegment]
    def parse_child_segment
      consume
      raise err("Expect token [, got #{current.lexeme.inspect}") unless current.type == :child_start

      consume # "["

      child_segment = AST::ChildSegment.new
      loop do
        selector = parse_current_selector
        child_segment << selector if selector # nil selector means empty brackets

        break unless current.type == :union # no more selectors in these parentheses

        # consume union operator and move on to next selector
        consume # ","

        # not allowed to have comma with nothing after it
        raise err('Comma must be followed by another expression in filter selector') if current.type == :child_end
      end

      # Expect ']' after the selector definitions
      raise err("Unexpected character #{current.lexeme.inspect} within brackets") unless current.type == :child_end

      # if the child_segment contains just one selector, then return the selector instead.
      # This way a series of selectors feed results to each other without
      # combining results in a node list.
      expr =
        case child_segment.size
        when 0 then raise err('Empty child segment')
        when 1 then child_segment.first
        else child_segment
        end

      # Parse any subsequent expression which consumes this child segment
      expr.next = parse_next_selector

      expr
    end

    # Parse a selector and return it.
    # @return [Selector, ChildSegment, nil] nil if no more selectors to use
    def parse_next_selector
      case next_token.type
      when :child_start then parse_child_segment
      when :dot then parse_dot_notation
      when :descendants then parse_descendant_segment
      when :eof, :child_end then nil
      end
    end

    # Parse a selector which is inside brackets
    def parse_current_selector
      case current.type
      when :array_slice_separator then parse_array_slice_selector
      when :filter then parse_filter_selector
      when :wildcard then parse_wildcard_selector
      when :minus
        # apply the - sign to the following number and retry
        parse_minus_operator
        parse_current_selector
      when :number
        if lookahead.type == :array_slice_separator
          parse_array_slice_selector
        else
          AST::IndexSelector.new(current_literal_and_consume)
        end
      when :identifier, :string
        AST::NameSelector.new(current_literal_and_consume)
      when :child_end then nil # empty brackets, do nothing.
      else
        raise err("Expect selector, got #{current.lexeme.inspect}")
      end
    end

    # Parse wildcard selector and any following selector
    # @return [AST::WildcardSelector]
    def parse_wildcard_selector
      AST::WildcardSelector.new.tap do |selector|
        consume # *
        selector.next = parse_next_selector unless %i[child_end union].include?(current.type)
      end
    end

    # An array slice start:end:step selects a series of elements from
    # an array, giving a start position, an end position, and an optional step
    # value that moves the position from the start to the end.
    #
    # @example
    #   $[1:3]
    #   $[5:]
    #   $[1:5:2]
    #   $[5:1:-2]
    #   $[::-1]
    #
    # @return [AST::ArraySliceSelector]
    def parse_array_slice_selector
      start, end_, step = Array.new(3) { parse_array_slice_component }.map { _1&.literal }

      unless %i[child_end union].include?(current.type)
        raise err("Array slice selector must be followed by \",\" or \"]\", got #{current.lexeme}")
      end

      AST::ArraySliceSelector.new(start, end_, step)
    end

    # Extract the number from an array slice selector.
    # Consume up to and including the next : token.
    # If no number is found, return nil.
    # @return [Number, nil] nil if the start is implicit
    def parse_array_slice_component
      token =
        case current.type
        when :array_slice_separator, :child_end, :union then nil
        when :minus # apply - sign to number and retry
          parse_minus_operator
          parse_array_slice_component
        when :number then current
        else raise err("Unexpected token in array slice selector: #{current.lexeme.inspect}")
        end
      consume if current.type == :number
      consume if current.type == :array_slice_separator
      token
    end

    # Parse a name selector.
    # The name selector may have been in dot notation or parentheses, that part is already parsed.
    # Next token is the name.
    #
    # @return [AST::NameSelector]
    def parse_name_selector
      AST::NameSelector.new(consume.lexeme).tap do |selector|
        selector.next = parse_next_selector
      end
    end

    # Feed tokens to the FilterSelector until hitting a terminator
    def parse_filter_selector
      selector = AST::FilterSelector.new
      terminator_types = %I[child_end union eof]
      while next_token && !terminator_types.include?(next_token.type)
        consume
        node =
          if BINARY_OPERATORS.include?(current.lexeme)
            parse_binary_operator(selector.value)
          else
            parse_expr_recursively
          end

        # may replace existing node with a binary operator that contains the existing node
        selector.value = node
      end

      # Check for literals, they are not allowed to be a complete condition in a filter selector.
      # This includes jsonpath functions that return a numeric value.
      raise err("Literal value #{selector.value} must be used within a comparison") if selector.value.literal?

      consume

      selector
    end

    # @return [AST::UnaryOperator, AST::Number]
    def parse_unary_operator
      case current.type
      when :not then parse_not_operator
      when :minus
        parse_minus_operator
        parse_number
      else
        raise err("Unknown unary operator: #{current.lexeme.inspect}")
      end
    end

    def parse_not_operator
      AST::UnaryOperator.new(current.type).tap do |op|
        consume
        op.operand = parse_expr_recursively
      end
    end

    def parse_binary_operator(left)
      op = AST::BinaryOperator.new(current.type, left)
      op_precedence = current_precedence

      consume
      op.right = parse_expr_recursively(op_precedence)

      op
    end

    # Parse a JSONPath function call
    def parse_function
      parsing_function = "parse_function_#{current.literal}"
      send(parsing_function)
    end

    # Parse an expression
    def parse_expr
      parsing_function = determine_parsing_function
      raise err("Unrecognized token: #{current.lexeme.inspect}") unless parsing_function

      send(parsing_function)
    end

    # Parse an expression which may contain binary operators and varying expression precedence.
    # This is only needed within a filter expression.
    def parse_expr_recursively(precedence = LOWEST_PRECEDENCE)
      parsing_function = determine_parsing_function
      raise err("Unrecognized token: #{current.lexeme.inspect}") unless parsing_function

      expr = send(parsing_function)
      return unless expr

      # Keep parsing until next token is higher precedence, or a terminator
      while next_not_terminator? && precedence < next_precedence
        infix_parsing_function = determine_infix_function(next_token)
        return expr if infix_parsing_function.nil?

        consume
        expr = send(infix_parsing_function, expr)
      end

      expr
    end

    # Return a Parser::Error with the specified message, include the query.
    #
    # @param msg [String] error message
    # @return [Parser::Error]
    def err(msg)
      Janeway::Error.new(msg, @jsonpath)
    end

    alias parse_true parse_boolean
    alias parse_false parse_boolean
  end
end
