# frozen_string_literal: true

require 'logger'
require_relative 'helpers/functions'

module JsonPath2
  # Transform a list of tokens into an Abstract Syntax Tree
  class Parser
    attr_accessor :tokens, :ast, :errors

    include Helpers::Functions

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
      log @tokens.map(&:lexeme).join

      # FIXME: change this to parse the root and then feed the next token to root, to make a tree.
      # Currently, root is just the first token in the list but does not contain anything.
      # This makes it so that root's #to_s cannot tell if it is followed by dot notation or parentheses notation, which makes it impossible to properly implement the #to_s
      #
      # This loop should iterate only twice: once to parse the root (recursively), once to parse the terminator
      while pending_tokens?
        consume
        log "CONSUME, current=#{current}"
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

    # FIXME: rename to #next_token
    def nxt
      lookahead
    end
    alias next_token nxt

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
      #log "for #{current}"
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
        :parse_selector_list
      elsif current.type == :dot # .
        :parse_dot_notation
      elsif current.type == :descendants # ..
        :parse_descendant_segment
      elsif current.type == :filter # ?
        :parse_filter_selector
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
    # Then modify its value.
    def parse_minus_operator
      log "(#{current})"
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
      log "current=#{current}, next_token=#{next_token}"
      # FIXME: replace with #parse_selector?
      selector =
        case current.type
        when :wildcard then parse_wildcard_selector
        when :child_start then parse_selector_list
        when :string, :identifier then parse_selector
        else
          raise "Invalid query: descendant segment must have selector, got ..#{current.lexeme}"
        end

      AST::DescendantSegment.new(selector)
    end

    # Dot notation reprsents a name selector, and is an alternative to bracket notation.
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
      log "current=#{current}, next_token=#{next_token}"

      case next_token.type
      # FIXME: implement a different name lexer which is limited to only the chars allowed under dot notation
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.5.1.1
      when :identifier then parse_name_selector
      when :wildcard then parse_wildcard_selector
      else
        raise "cannot parse #{current.type}"
      end
    end

    # FIXME: delete this and its alias, when unit tests are passing again
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
      log "current=#{current}, next_token=#{next_token}"

      # detect optional following selector, using dot or bracket notation
      selector =
        if nxt.type == :dot
          #consume
          parse_dot_notation
        elsif nxt.type == :child_start
          #consume
          parse_selector_list
        end

      AST::Root.new(selector)
    end

    # Parse the current node operator "@", and optionally a selector which is applied to it
    def parse_current_node
      log "current=#{current}, next_token=#{next_token}"

      # detect optional following selector, using dot or bracket notation
      selector =
        if nxt.type == :dot
          #consume # "."
          parse_dot_notation
        elsif nxt.type == :child_start
          #consume # "["
          parse_selector_list
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
    # @return [AST::SelectorList]
    def parse_selector_list
      consume
      log "current=#{current}, next_token=#{next_token}"
      raise "Expect token [, got #{current.lexeme.inspect}" unless current.type == :child_start

      consume # "["

      selector_list = AST::SelectorList.new
      loop do
        selector_list << parse_selector

        log "parsed selector #{selector_list.last}, current=#{current}"
        break unless current.type == :union # no more selectors in these parentheses

        # consume the union operator, then move on to the next selector
        consume # ","
      end

      # Do not consume the final ']', the top-level parsing loop will eat that
      unless current.type == :child_end
        # developer error, check the parsing function
        raise "expect current token to be ], got #{current.type.inspect}"
      end

      log "got selectors #{selector_list.children.map(&:type).inspect}, current=#{current}"

      selector_list
    end

    # Parse a selector.
    def parse_selector
      log "current=#{current}, next_token=#{next_token}"
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
        parse_wildcard_selector
      else
        raise "Unhandled selector: #{current}"
      end
    end

    # Parse wildcard selector and any following selector
    def parse_wildcard_selector
      log "current=#{current}, next_token=#{next_token}"
      selector = AST::WildcardSelector.new(current.literal)
      consume
      log " ... current=#{current}"

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
      log "current=#{current}, next_token=#{next_token}"
      start, end_, step = Array.new(3) { parse_array_slice_component }
      log "got [#{start&.lexeme},#{end_&.lexeme},#{step&.lexeme}] (current=#{current})"

      raise "After array slice, expect ], got #{current.lexeme}" unless current.type == :child_end # ]

      AST::ArraySliceSelector.new(start, end_, step)
    end

    # Extract the number from an array slice selector.
    # Consume up to and including the next : token.
    # If no number is found, return nil.
    # @return [Number, nil] nil if the start is implicit
    def parse_array_slice_component
      log "current=#{current}, next_token=#{next_token}"
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

    # Parse a name selector.
    # The name selector may have been in dot notation or parentheses, that part is already parsed.
    # Next token is just the name.
    # @return [AST::NameSelector]
    def parse_name_selector
      consume
      log "current=#{current}, next_token=#{next_token}"
      AST::NameSelector.new(current.lexeme).tap do |selector|
        # If there is a following expression, consume
        case next_token.type
        when :dot then selector << parse_dot_notation
        when :child_start then selector << parse_selector_list
        when :descendant then selector << parse_descendant_segment
        when :group_end, :union then nil # do nothing, no children to add
        end
      end
    end

    # Feed tokens to the FilterSelector until hitting a terminator
    def parse_filter_selector
      log "current=#{current}, next_token=#{next_token}"

      selector = AST::FilterSelector.new
      terminator_types = %I[child_end union eof]
      while nxt && !terminator_types.include?(next_token.type)
        consume
        log "(loop) parse current=#{current}, have #{selector}"
        node =
          if BINARY_OPERATORS.include?(current.lexeme)
            parse_binary_operator(selector.value)
          else
            parse_expr_recursively
          end
        log "(loop) got node #{node}, next_token is #{next_token}"

        # may replace existing node with a binary operator that incorporates the original node
        selector.value = node
      end

      # #parse_expr_recursively expects its "top-level" loop to consume,
      # so it must leave an already-parsed token to be consumed
      consume
      log "finished with #{selector.children}, current #{current}"

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

    # Parse a JSONPath function call
    def parse_function
      parsing_function = "parse_function_#{current.literal}"
      log "with #{current} -> #{parsing_function} "
      result = send(parsing_function)
      log "returns #{result.inspect}"
      result
    end

    def parse_expr_recursively(precedence = LOWEST_PRECEDENCE)
      parsing_function = determine_parsing_function
      return unrecognized_token_error unless parsing_function

      tk = current
      log "with #{tk} will call #{parsing_function}"
      expr = send(parsing_function)
      log "with #{tk} called #{parsing_function}, current #{current}, expr #{expr.inspect}"
      return unless expr # When expr is nil, it means we have reached a \n or a eof.

      # Note that here we are checking the NEXT token.
      if nxt_not_terminator? && precedence < nxt_precedence
        log "will loop, current:#{current} checking #{nxt}, precedence " + [precedence, nxt_precedence].inspect
      end
      while nxt_not_terminator? && precedence < nxt_precedence
        infix_parsing_function = determine_infix_function(nxt)
        log "(loop) next token #{nxt.lexeme}, will parse with #{infix_parsing_function.inspect}(#{expr.inspect})"

        return expr if infix_parsing_function.nil?

        log "(loop) infix current #{current}, send #{infix_parsing_function}(#{expr.inspect})"
        consume
        expr = send(infix_parsing_function, expr)
      end

      log "returns #{expr.inspect}, current #{current}"
      expr
    end

    def log(msg, level: :info)
      raise ArgumentError, "invalid log level: #{level.inspect}" unless %I[info debug warn error].include?(level.to_sym)

      caller = caller_locations(1..1).first.label
      @log.send(level.to_sym, "##{caller}") { msg }
    end

    alias parse_true parse_boolean
    alias parse_false parse_boolean
    alias parse_if parse_conditional
  end
end
