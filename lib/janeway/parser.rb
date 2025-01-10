# frozen_string_literal: true

require_relative 'functions'

module Janeway
  # Transform a list of tokens into an Abstract Syntax Tree
  class Parser
    class Error < Janeway::Error; end

    attr_accessor :tokens, :ast

    include Functions

    UNARY_OPERATORS = %w[! -].freeze
    BINARY_OPERATORS = %w[== != > < >= <= ,].freeze
    LOGICAL_OPERATORS = %w[&& ||].freeze

    LOWEST_PRECEDENCE = 0
    PREFIX_PRECEDENCE = 7
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

    # @param query [String] jsonpath query to be lexed and parsed
    #
    # @return [AST]
    def self.parse(query)
      raise ArgumentError, "expect string, got #{query.inspect}" unless query.is_a?(String)

      tokens = Janeway::Lexer.lex(query)
      new(tokens).parse
    end

    def initialize(tokens)
      @tokens = tokens
      @ast = AST::Query.new
      @next_p = 0
    end

    def parse

      consume
      @ast.root = parse_expr_recursively
      consume
      raise "unparsed tokens" unless current.type == :eof

      @ast
    end

    private

    def build_token(type, lexeme = nil)
      Token.new(type, lexeme, nil, nil)
    end

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

    def consume_if_next_is(expected)
      if next_token.type == expected.type
        consume
        true
      else
        unexpected_token_error(expected)
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

    def unexpected_token_error(expected = nil)
      if expected
        raise Error, "Unexpected token #{current.lexeme.inspect} (expected #{expected.inspect}) (next is #{next_token.inspect})"
      else
        raise Error, "Unexpected token #{current.lexeme.inspect} (next is #{next_token.inspect})"
      end
    end

    def check_syntax_compliance(ast_node)
      return if ast_node.expects?(next_token)

      unexpected_token_error
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
        raise "Don't know how to parse #{current}"
      end
    end

    # @return [nil, Symbol]
    def determine_infix_function(token = current)
      return unless (BINARY_OPERATORS + LOGICAL_OPERATORS).include?(token.lexeme)

      :parse_binary_operator
    end

    def parse_identifier
      ident = AST::Identifier.new(current.lexeme)
      check_syntax_compliance(ident)
      ident
    end

    def parse_string
      AST::StringType.new(current.literal)
    end

    def parse_number
      AST::Number.new(current.literal)
    end

    # Consume minus operator and apply it to the (expected) number token following it.
    # Don't consume the number token.
    def parse_minus_operator
      raise "Expect token '-', got #{current.lexeme.inspect}" unless current.type == :minus

      # RFC: negative 0 is allowed within a filter selector comparison, but is NOT allowed within an index selector or array slice selector.
      # Detect that condition here
      if next_token.type == :number && next_token.literal == 0
        if [previous.type, lookahead(2).type].any? { _1 == :array_slice_separator}
          raise Error, 'Negative zero is not allowed in an array slice selector'
        elsif %i[union child_start].include?(previous.type)
          raise Error, 'Negative zero is not allowed in an index selector'
        end
      end

      # '-' must be followed by a number token.
      # Parse number and apply - sign to its literal value
      consume
      parse_number
      current.literal *= -1
      current
    end

    # @return [AST::Null]
    def parse_null
      AST::Null.new
    end

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

      # DescendantSegment must be followed by a selector S which it applies to all descendants.
      #
      # Normally the parser makes the selector after S be a child of S.
      # However that is not the desired behavior for DescendantSelector.
      # Consider '$.a..b[1]'. The first element must be taken from the set of all 'b' keys.
      # If the ChildSegment was a child of the `b` NameSelector, then it would be taking
      # index 1 from every 'b' found rather than from the set of all 'b's.
      #
      # To get around this, the Parser must embed a Selector object that
      # doesn't include the following selector as a child. Then the following
      # selector must be made a child of the DescendantSegment.
      selector =
        case next_token.type
        when :wildcard then parse_wildcard_selector(and_child: false)
        when :child_start then parse_child_segment(and_child: false)
        when :string, :identifier then parse_name_selector(and_child: false)
        else
          raise "Invalid query: descendant segment must have selector, got ..#{next_token.type}"
        end

      AST::DescendantSegment.new(selector).tap do |ds|
        # If there is another selector after this one, make it a child
        ds.child = parse_next_selector
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
      raise "#parse_dot_notation expects to consume :dot, got #{current}" unless current.type == :dot

      case next_token.type
      # FIXME: implement a different name lexer which is limited to only the chars allowed under dot notation
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.5.1.1
      when :identifier then parse_name_selector
      when :wildcard then parse_wildcard_selector
      else
        raise "cannot parse #{current.type}"
      end
    end

    def parse_grouped_expr
      consume

      expr = parse_expr_recursively
      return unless consume_if_next_is(build_token(:group_end, ')'))

      expr
    end

    # TODO: Temporary impl; reflect more deeply about the appropriate way of parsing a terminator.
    def parse_terminator
      nil
    end

    def parse_root

      # detect optional following selector
      selector =
        case next_token.type
        when :dot then parse_dot_notation
        when :child_start then parse_child_segment
        when :descendants then parse_descendant_segment
        end

      AST::RootNode.new(selector)
    end

    # Parse the current node operator "@", and optionally a selector which is applied to it
    def parse_current_node

      # detect optional following selector
      selector =
        case next_token.type
        when :dot then parse_dot_notation
        when :child_start then parse_child_segment
        when :descendants then parse_descendant_segment
        end

      AST::CurrentNode.new(selector)
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
    # @param and_child [Boolean] make following token a child of this selector list
    # @return [AST::ChildSegment]
    def parse_child_segment(and_child: true)
      consume
      raise "Expect token [, got #{current.lexeme.inspect}" unless current.type == :child_start

      consume # "["

      child_segment = AST::ChildSegment.new
      loop do
        selector = parse_selector
        child_segment << selector if selector # nil selector means empty brackets

        break unless current.type == :union # no more selectors in these parentheses

        # consume union operator and move on to next selector
        consume # ","

        # not allowed to have comma with nothing after it
        if current.type == :child_end
          raise Error.new("Comma must be followed by another expression in filter selector")
        end
      end

      # Do not consume the final ']', the top-level parsing loop will eat that
      unless current.type == :child_end
        # developer error, check the parsing function
        raise "expect current token to be ], got #{current.type.inspect}"
      end

      # if the child_segment contains just one selector, then return the selector instead.
      # This way a series of selectors feed results to each other without
      # combining results in a node list.
      node =
        case child_segment.size
        when 0 then raise Error.new('Empty child segment')
        when 1 then child_segment.first
        else child_segment
        end

      if and_child
        # Parse any subsequent expression which consumes this child segment
        node.child = parse_next_selector
      end

      node
    end

    # Parse a selector and return it.
    # @return [Selector, ChildSegment, nil] nil if no more selectors to use
    def parse_next_selector
      case next_token.type
      when :child_start then parse_child_segment
      when :dot then parse_dot_notation
      end
    end

    # Return true if the given token represents the start of any type of selector,
    # or a collection of selectors.
    #
    # @param token [Token]
    # @return [Boolean]
    def selector?(token)
      type = token.type.to_s
      type.include?('selector') || %w[dot child_start].include?(type)
    end

    # Parse a selector which is inside brackets
    def parse_selector
      case current.type
      when :array_slice_separator then parse_array_slice_selector
      when :filter then parse_filter_selector
      when :wildcard then parse_wildcard_selector
      when :minus
        # apply the - sign to the following number and retry
        parse_minus_operator
        parse_selector
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
        raise "Unhandled selector: #{current}"
      end
    end

    # Parse wildcard selector and any following selector
    # @param and_child [Boolean] make following token a child of this selector
    def parse_wildcard_selector(and_child: true)
      selector = AST::WildcardSelector.new
      consume
      selector.child = parse_next_selector if and_child
      selector
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


      raise "After array slice, expect ], got #{current.lexeme}" unless current.type == :child_end # ]

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
        else raise "Unexpected token in array slice selector: #{current}"
        end
      consume if current.type == :number
      consume if current.type == :array_slice_separator
      token
    end

    # Parse a name selector.
    # The name selector may have been in dot notation or parentheses, that part is already parsed.
    # Next token is just the name.
    #
    # @param and_child [Boolean] make following token a child of this selector
    # @return [AST::NameSelector]
    def parse_name_selector(and_child: true)
      consume
      selector = AST::NameSelector.new(current.lexeme)
      if and_child
        # If there is a following expression, parse that too
        case next_token.type
        when :dot then selector.child = parse_dot_notation
        when :child_start then selector.child = parse_child_segment
        when :descendants then selector.child = parse_descendant_segment
        end
      end
      selector
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

        # may replace existing node with a binary operator that incorporates the original node
        selector.value = node
      end

      # Check for literal, they are not allowed to be a complete condition in a filter selector
      if selector.value.literal?
        raise Error, "Literal #{selector.value} must be used within a comparison"
      end

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
        raise "unknown unary operator: #{current.inspect}"
      end
    end

    def parse_not_operator
      AST::UnaryOperator.new(current.type).tap do |op|
        consume
        op.operand = parse_expr_recursively(PREFIX_PRECEDENCE)
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
      result = send(parsing_function)
      result
    end

    # Parse an expression
    def parse_expr
      parsing_function = determine_parsing_function
      raise Error, "Unrecognized token: #{current.lexeme.inspect}" unless parsing_function

      send(parsing_function)
    end

    def parse_expr_recursively(precedence = LOWEST_PRECEDENCE)
      parsing_function = determine_parsing_function
      raise Error, "Unrecognized token: #{current.lexeme.inspect}" unless parsing_function

      tk = current
      expr = send(parsing_function)
      return unless expr # When expr is nil, it means we have reached a \n or a eof.

      # Note that here we are checking the NEXT token.
      if next_not_terminator? && precedence < next_precedence
      end
      while next_not_terminator? && precedence < next_precedence
        infix_parsing_function = determine_infix_function(next_token)

        return expr if infix_parsing_function.nil?

        consume
        expr = send(infix_parsing_function, expr)
      end

      expr
    end

    alias parse_true parse_boolean
    alias parse_false parse_boolean
  end
end
