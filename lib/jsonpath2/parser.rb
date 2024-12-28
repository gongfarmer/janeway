# frozen_string_literal: true

require 'logger'

module JsonPath2
  # Transform tokens into an Abstract Syntax Tree
  class Parser
    attr_accessor :tokens, :ast, :errors

    UNARY_OPERATORS = %w[! -].freeze
    BINARY_OPERATORS = %w[== != > < >= <=].freeze
    LOGICAL_OPERATORS = %w[&& ||].freeze

    LOWEST_PRECEDENCE = 0
    PREFIX_PRECEDENCE = 7
    OPERATOR_PRECEDENCE = {
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

    # @param query [String] jsonpath query to lex and parse
    # @param logger [Logger]
    #
    # @return [AST]
    def self.parse(query, logger = Logger.new(IO::NULL))
      raise ArgumentError, "expect string, got #{query.inspect}" unless query.is_a?(String)

      tokens = JsonPath2::Lexer.lex(query)
      new(tokens, logger).parse
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

    # Return literal of current token. Consume.
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
      OPERATOR_PRECEDENCE[current.lexeme] || LOWEST_PRECEDENCE
    end

    def nxt_precedence
      OPERATOR_PRECEDENCE[nxt.lexeme] || LOWEST_PRECEDENCE
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
      elsif current.type == :group_start # (
        :parse_grouped_expr
      elsif %I[\n eof].include?(current.type)
        :parse_terminator
      elsif UNARY_OPERATORS.include?(current.lexeme)
        :parse_unary_operator
      elsif current.type == :child_start # [
        :parse_bracketed_selector
      elsif current.type == :dot # .
        :parse_dot_notation
      elsif current.type == :descendants # ..
        :parse_descendant_segment
      elsif current.type == :root # $
        :parse_root
      else
        raise "Don't know how to parse #{current}"
      end
    end

    def determine_infix_function(token = current)
      if (BINARY_OPERATORS + LOGICAL_OPERATORS).include?(token.lexeme)
        :parse_binary_operator
      elsif token.type == :group_start # (
        :parse_function_call
      end
    end

    def parse_identifier
      ident = AST::Identifier.new(current.lexeme)
      check_syntax_compliance(ident)
      ident
    end

    def parse_string
      AST::String.new(current.literal)
    end

    def parse_number
      AST::Number.new(current.literal)
    end

    # Consume minus operator and apply it to the (expected) number token following it.
    # Then modify its value.
    def parse_minus_operator
      @log.debug "#parse_minus_operator(#{current})"
      raise "Expect token '-', got #{current.lexeme.inspect}" unless current.type == :minus

      # '-' must be followed by a number token.
      # Parse number and apply - sign to its literal value
      consume
      parse_number
      current.literal = 0 - current.literal
      current
    end

    def parse_boolean
      AST::Boolean.new(current.literal == 'true')
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
      @log.debug "#parse_descendant_segment: current=#{current}"
      selector =
        case current.type
        when :wildcard then AST::WildcardSelector.new(current_literal_and_consume)
        when :child_start then parse_bracketed_selector
        when :string, :identifier then parse_selector
        else
          raise "Invalid query: descendant segment must have selector, got ..#{current.lexeme}"
        end

      AST::DescendantSegment.new(selector)
    end

    # Dot notation is an alternate representation of a bracketed name selector.
    #
    # The IETF doc does not explicitly define whether other selector types
    # (eg. IndexSelector) are allowed here, but the examples suggest that only
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
      return unless consume_if_nxt_is(build_token(:group_end, ')'))

      expr
    end

    # TODO: Temporary impl; reflect more deeply about the appropriate way of parsing a terminator.
    def parse_terminator
      nil
    end

    def parse_root
      AST::Root.new
    end

    # Parse one or more selectors surrounded by brackets.
    #
    # More than 1 selector may be within the brackets, as long as they are separated by commas.
    # If multiple selectors are given, then their results are combined (possibly introducing
    # duplicate elements in the result.)
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
    # @return [AST::Shared::ExpressionCollection]
    def parse_bracketed_selector
      @log.debug "#parse_bracketed_selector: start, current=#{current}"
      raise "Expect token [, got #{current.lexeme.inspect}" unless current.type == :child_start

      consume # "["

      selector_list = AST::SelectorList.new
      loop do
        selector_list << parse_selector

        break unless current.type == :union # no more selectors in these brackets

        # consume the union operator, then move on to the next selector
        consume # ","
      end

      # Do not consume the final ']', the top-level parsing loop will eat that
      unless current.type == :child_end
        # developer error, check the parsing function
        raise "expect current token to be ], got #{current.type.inspect}"
      end

      @log.debug "#parse_bracketed_selector: got selectors #{selector_list.children.map(&:type).inspect}, current=#{current}"

      selector_list
    end

    # Parse a selector.
    def parse_selector
      @log.debug "#parse_selector(current=#{current})"
      case current.type
      when :array_slice_separator then parse_array_slice_selector
      when :filter then parse_filter_selector
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
      when :wildcard
        AST::WildcardSelector.new(current_literal_and_consume)
      else
        raise "Unhandled selector: #{current}"
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
      @log.debug "#parse_array_slice_selector start (current=#{current})"
      start, end_, step = 3.times.map { parse_array_slice_component }
      @log.debug "#parse_array_slice_selector got [#{start&.lexeme},#{end_&.lexeme},#{step&.lexeme}] (current=#{current})"

      raise "After array slice, expect ], got #{current.lexeme}" unless current.type == :child_end # ]

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
        when :child_end then return nil
        when :array_slice_separator then nil
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

    # Feed tokens to the FilterSelector until hitting a terminator
    def parse_filter_selector
      @log.debug "#parse_filter_selector: #{current}"
      consume # "?"

      selector = AST::FilterSelector.new(parse_expr_recursively)

      consume # because #parse_expr_recursively expects its "top-level" loop to consume, it leaves an already-parsed token
      @log.debug "#parse_filter_selector: finished with #{selector.children}, current #{current}"

      selector
    end

    # @return [AST::UnaryOperator]
    def parse_unary_operator
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

    def parse_expr_recursively(precedence = LOWEST_PRECEDENCE)
      parsing_function = determine_parsing_function
      return unrecognized_token_error unless parsing_function

      tk = current
      @log.debug "#parse_expr_recursively pre-send  #{tk} with #{parsing_function}"
      expr = send(parsing_function)
      @log.debug "#parse_expr_recursively post-send #{tk} with #{parsing_function}, current #{current}, expr #{expr.inspect}"
      return unless expr # When expr is nil, it means we have reached a \n or a eof.

      # Note that here we are checking the NEXT token.
      @log.debug "#parse_expr_recursively will loop, current:#{current} checking #{nxt}, precedence " + [precedence, nxt_precedence].inspect
      while nxt_not_terminator? && precedence < nxt_precedence
        infix_parsing_function = determine_infix_function(nxt)
        @log.debug "#parse_expr_recursively next token #{nxt.lexeme}, will parse with #{infix_parsing_function.inspect}(#{expr.inspect})"

        return expr if infix_parsing_function.nil?

        @log.debug "#parse_expr_recursively infix current #{current}, send #{infix_parsing_function}(#{expr.inspect})"
        consume
        expr = send(infix_parsing_function, expr)
      end

      @log.debug "#parse_expr_recursively returns #{expr.inspect}, current #{current}"
      expr
    end

    alias parse_true parse_boolean
    alias parse_false parse_boolean
    alias parse_if parse_conditional
  end
end
