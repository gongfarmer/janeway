# frozen_string_literal: true

require 'logger'

module JsonPath2
  # Parse the tokens to create an Abstract Syntax Tree
  class Parser
    attr_accessor :tokens, :ast, :errors

    UNARY_OPERATORS = %I[! -].freeze
    BINARY_OPERATORS = %I[+ - * / == != > < >= <=].freeze
    LOGICAL_OPERATORS = %I[&& ||].freeze
    ROOT_OPERATOR = :'$'

    LOWEST_PRECEDENCE = 0
    PREFIX_PRECEDENCE = 7
    OPERATOR_PRECEDENCE = {
      '||': 1,
      '&&': 2,
      '==': 3,
      '!=': 3,
      '>': 4,
      '<': 4,
      '>=': 4,
      '<=': 4,
      '+': 5,
      '-': 5,
      '*': 6,
      '/': 6,
      '(': 8
    }.freeze

    # @param query [String] jsonpath query to lex and parse
    # @return [AST]
    def self.parse(query)
      tokens = JsonPath2::Lexer.lex(query)
      new(tokens).parse
    end

    def initialize(tokens, logger = Logger.new(IO::NULL))
      @tokens = tokens
      @ast = AST::Query.new
      @next_p = 0
      @errors = []
      @log = logger
    end

    def parse
      while pending_tokens?
        consume
        @log.debug "CONSUME at top level, current=#{current}"
        node = parse_expr_recursively
        ast << node if node
      end

      ast
    end

    private

    def build_token(type, lexeme = nil)
      Token.new(type, lexeme, nil, nil)
    end

    def pending_tokens?
      @next_p < tokens.length
    end

    def nxt_not_terminator?
      nxt && nxt.type != :"\n" && nxt.type != :eof
    end

    def consume(offset = 1)
      t = lookahead(offset)
      @next_p += offset # FIXME: changed this
      t
    end

    # Return lexeme of current token. Consume.
    # @return [String, Integer] literal value of token that is `current` when function is called.
    def current_literal_and_consume
      current.literal.tap { consume }
    end

    def consume_if_nxt_is(expected)
      if nxt.type == expected.type
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

    def nxt
      lookahead
    end

    def lookahead(offset = 1)
      lookahead_p = (@next_p - 1) + offset
      return nil if lookahead_p.negative? || lookahead_p >= tokens.length

      tokens[lookahead_p]
    end

    def current_precedence
      OPERATOR_PRECEDENCE[current.type] || LOWEST_PRECEDENCE
    end

    def nxt_precedence
      OPERATOR_PRECEDENCE[nxt.type] || LOWEST_PRECEDENCE
    end

    def unrecognized_token_error
      errors << Error::Syntax::UnrecognizedToken.new(current)
    end

    def unexpected_token_error(expected = nil)
      errors << Error::Syntax::UnexpectedToken.new(current, nxt, expected)
    end

    def check_syntax_compliance(ast_node)
      return if ast_node.expects?(nxt)

      unexpected_token_error
    end

    def determine_parsing_function
      @log.debug "PARSE: #{current.type}"
      parse_methods = %I[identifier number string true false nil fn if while]
      if parse_methods.include?(current.type)
        "parse_#{current.type}".to_sym
      elsif current.type == :'('
        :parse_grouped_expr
      elsif %I[\n eof].include?(current.type)
        :parse_terminator
      elsif UNARY_OPERATORS.include?(current.type)
        :parse_unary_operator
      elsif current.type == :'['
        :parse_bracketed_selector
      elsif current.type == :'.'
        :parse_dot_notation
      elsif current.type == :'..'
        :parse_descendant_segment
      elsif current.type == ROOT_OPERATOR
        :parse_root
      else
        raise "Don't know how to parse #{current.inspect}"
      end
    end

    def determine_infix_function(token = current)
      if (BINARY_OPERATORS + LOGICAL_OPERATORS).include?(token.type)
        :parse_binary_operator
      elsif token.type == :'('
        :parse_function_call
      end
    end

    def parse_identifier
      if lookahead.type == :'='
        parse_var_binding
      else
        ident = AST::Identifier.new(current.lexeme)
        check_syntax_compliance(ident)
        ident
      end
    end

    def parse_string
      AST::String.new(current.literal)
    end

    def parse_number
      AST::Number.new(current.literal)
    end

    # Consume to the (expected) number token following this operator.
    # Then modify its value.
    def parse_minus_operator
      @log.debug "#parse_minus_operator(#{current})"
      raise "Expect token '-', got #{current.lexeme.inspect}" unless current.type == :'-'

      # '-' must be followed by a number token.
      # Parse number and apply - sign to its literal value
      consume
      parse_number
      current.literal = 0 - current.literal
      current
    end


    def parse_boolean
      AST::Boolean.new(current.lexeme == 'true')
    end

    def parse_nil
      AST::Nil.new
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
      consume # '..' token
      selector  =
        case current.type
        when :'*' then AST::WildcardSelector.new(current_literal_and_consume)
        when :'[' then parse_bracketed_selector
        when :string, :identifier then parse_selector
        else
          raise "Invalid query: descendant segment must have selector, got ..#{current.lexeme}"
        end

      AST::DescendantSegment.new(selector)
    end

    # Dot notation is an alternate representation of a bracketed name selector.
    #
    # The IETF doc does not explicitly define whether other selector types
    # (eg. IndexSelector) but the examples suggest that only
    # NameSelector can be used with dot notation.
    def parse_dot_notation
      consume

      raise "Expect name to follow dot in dot notation, got #{current}" unless current.type == :identifier

      AST::NameSelector.new(current.lexeme)
    end

    def parse_conditional
      conditional = AST::Conditional.new
      consume
      conditional.condition = parse_expr_recursively
      return unless consume_if_nxt_is(build_token(:"\n", "\n"))

      conditional.when_true = parse_block

      # TODO: Probably is best to use nxt and check directly; ELSE is optional and should not result in errors being added to the parsing. Besides that: think of some sanity checks (e.g., no parser errors) that maybe should be done in EVERY parser test.
      if consume_if_nxt_is(build_token(:else, 'else'))
        return unless consume_if_nxt_is(build_token(:"\n", "\n"))

        conditional.when_false = parse_block
      end

      conditional
    end

    # FIXME: remove, but consider parsing root this way
    def parse_block
      consume
      block = AST::Block.new
      while current.type != :end && current.type != :eof && nxt.type != :else
        expr = parse_expr_recursively
        block << expr unless expr.nil?
        consume
      end
      unexpected_token_error(build_token(:eof)) if current.type == :eof

      block
    end

    def parse_grouped_expr
      consume

      expr = parse_expr_recursively
      return unless consume_if_nxt_is(build_token(:')', ')'))

      expr
    end

    # TODO: Temporary impl; reflect more deeply about the appropriate way of parsing a terminator.
    def parse_terminator
      nil
    end

    def parse_root
      AST::Root.new
    end

    # Parse one of these:
    #
    # A name selector, e.g. 'name', selects a named child of an object.
    #
    # An index selector, e.g. 3, selects an indexed child of an array.
    #
    # A wildcard * ({{wildcard-selector}}) in the expression [*] selects all
    # children of a node and in the expression ..[*] selects all descendants of a
    # node.
    #
    # An array slice start:end:step ({{slice}}) selects a series of elements from
    # an array, giving a start position, an end position, and an optional step
    # value that moves the position from the start to the end.
    #
    # Filter expressions ?<logical-expr> select certain children of an object or array, as in:
    def parse_bracketed_selector
      raise "Expect token [, got #{current.lexeme.inspect}" unless current.type == :'['

      consume
      selector = parse_selector

      @log.debug "#parse_bracketed_selector: got selector #{selector}, current=#{current}"
      selector
    end

    # Parse selector which is not surrounded by brackets
    def parse_selector
      @log.debug "#parse_selector(current=#{current})"
      case current.type
      when :':' then parse_array_slice_selector
      when :'-'
        # apply the - sign to the following number and retry
        parse_minus_operator
        parse_selector
      when :number
        if lookahead.type == :':'
          parse_array_slice_selector
        else
          AST::IndexSelector.new(current_literal_and_consume)
        end
      when :identifier, :string
        AST::NameSelector.new(current_literal_and_consume)
      when :'*'
        AST::WildcardSelector.new(current_literal_and_consume)
      else
        raise "Unhandled selector: #{current.inspect}"
      end
    end

    # An array slice start:end:step ({{slice}}) selects a series of elements from
    # an array, giving a start position, an end position, and an optional step
    # value that moves the position from the start to the end.
    #
    # @example
    #   $[1:3]
    #   $[5:]
    #   $[1:5:2]
    #   $[5:1:-2]
    #   $[::-1]
    # @return [AST::ArraySliceSelector]
    def parse_array_slice_selector
      @log.debug "#parse_array_slice_selector start (current=#{current})"
      start, end_, step = 3.times.map { parse_array_slice_component }
      @log.debug "#parse_array_slice_selector got [#{start&.lexeme},#{end_&.lexeme},#{step&.lexeme}] (current=#{current})"

      raise "After array slice, expect ], got #{current.lexeme}" unless current.type == :']'

      AST::ArraySliceSelector.new(start, end_, step)
    end

    # Extract the number from an array slice selector.
    # Consume up to and including the next : token.
    # If no number is found, return nil.
    # @return [Number, nil] nil if the start is implicit
    def parse_array_slice_component
      @log.debug "#parse_array_slice_component(#{current})"
      token =
        case current.type
        when :']' then return nil
        when :':' then nil
        when :'-' # apply - sign to number and retry
          parse_minus_operator
          parse_array_slice_component
        when :number then current
        else raise "Unexpected token in array slice selector: #{current}"
        end
      consume if current.type == :number
      consume if current.type == :':'
      token
    end

    def array_slice_selector?(str)
      components = str.split(':')
      return false unless [1, 2].include?(components.size)
    end

    def parse_filter_expression
      # AST::FilterExpressionSelector.new

      raise NotImplementedError
    end

    def parse_unary_operator
      op = AST::UnaryOperator.new(current.type)
      consume
      op.operand = parse_expr_recursively(PREFIX_PRECEDENCE)

      op
    end

    def parse_binary_operator(left)
      op = AST::BinaryOperator.new(current.type, left)
      op_precedence = current_precedence

      consume
      op.right = parse_expr_recursively(op_precedence)

      op
    end

    def parse_expr_recursively(precedence = LOWEST_PRECEDENCE)
      parsing_function = determine_parsing_function
      return unrecognized_token_error unless parsing_function

      tk = current
      @log.debug "#parse_expr_recursively start #{tk} with #{parsing_function}"
      expr = send(parsing_function)
      @log.debug "#parse_expr_recursively end   #{tk} with #{parsing_function}, current #{current}, got #{expr}"
      return unless expr # When expr is nil, it means we have reached a \n or a eof.

      # Note that here we are checking the NEXT token.
      while nxt_not_terminator? && precedence < nxt_precedence
        infix_parsing_function = determine_infix_function(nxt)

        return expr if infix_parsing_function.nil?

        consume
        expr = send(infix_parsing_function, expr)
      end

      expr
    end

    alias parse_true parse_boolean
    alias parse_false parse_boolean
    alias parse_if parse_conditional
  end
end
