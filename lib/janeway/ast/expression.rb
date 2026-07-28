# frozen_string_literal: true

require_relative 'helpers'
require_relative 'error'

module Janeway
  module AST
    INDENT = '  '
    # Precomputed indent prefixes so #indented does not do `INDENT * level`
    # (a fresh String allocation) on every line printed.
    INDENTS = Array.new(16) { |i| (INDENT * i).freeze }.freeze

    # Base class for jsonpath expressions.
    #
    # Every AST node is a subclass of this.
    # This includes selectors, root and child identifiers, descendant segments,
    # and the nodes that occur within a filter selector such as the current
    # node identifier, operators and literals.
    class Expression
      # Value provided by subclass constructor.
      attr_accessor :value

      # Next expression in the AST, if any
      attr_reader :next

      def initialize(val = nil)
        # don't set the instance variable if unused, because it makes the
        # "#inspect" output cleaner in rspec test failures
        @value = val unless val.nil? # literal false must be stored though!
      end

      # @return [String]
      def type
        self.class.type_name
      end

      # Cached camelcase→underscore transform of the class name.
      # Same value on every instance of the class — compute once per class.
      #
      # @return [String]
      def self.type_name
        @type_name ||=
          Helpers.camelcase_to_underscore(name.split('::').last).freeze
      end

      # Return the given message, indented
      #
      # @param level [Integer]
      # @param msg [String]
      # @return [String]
      def indented(level, msg)
        (INDENTS[level] || (INDENT * level)) + msg
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end

      # Return true if this is a literal expression
      # @return [Boolean]
      def literal?
        false
      end

      # True if this is the root of a singular-query.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-well-typedness-of-function-
      #
      # @return [Boolean]
      def singular_query?
        false
      end

      # True if every selector in the @next chain is one of the allowed classes.
      # An empty chain (no @next) returns true. Extracted from the identical
      # implementations that used to live in CurrentNode and RootNode.
      #
      # @param allowed_classes [Array<Class>]
      # @return [Boolean]
      def chain_of?(*allowed_classes)
        selector = @next
        while selector
          return false unless allowed_classes.include?(selector.class)

          selector = selector.next
        end
        true
      end
    end
  end
end
