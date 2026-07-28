# frozen_string_literal: true

module Janeway
  module AST
    # AST node for binary operators:
    #   == != <= >= < > || &&
    class BinaryOperator < Janeway::AST::Expression
      attr_reader :name
      attr_accessor :left, :right

      def initialize(operator, left = nil, right = nil)
        super(nil)
        raise ArgumentError, "expect symbol, got #{operator.inspect}" unless operator.is_a?(Symbol)

        @name = operator # eg. :equal
        @left = left
        @right = right
      end

      # Validate the currently-set left and right operands as a well-formed
      # binary expression. Called by the parser once both sides are assigned —
      # the previous per-setter validation was order-dependent (left=
      # couldn't see right and vice-versa) and missed the both-literal case
      # when the parser assigned left first.
      #
      # @raise [Janeway::Error] on any semantic error
      def validate!
        raise Error, 'BinaryOperator requires both left and right' unless @left && @right

        validate_side(@left)
        validate_side(@right)
        validate_pair
      end

      def to_s
        # Make precedence explicit by adding parentheses
        "(#{@left} #{operator_to_s} #{@right})"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [
          indented(level, to_s),
          @left.tree(level + 1),
          @right.tree(level + 1),
        ]
      end

      # True if this operator is a comparison operator
      # @return [Boolean]
      def comparison_operator?
        operator_type == :comparison
      end

      # True if this operator is a logical operator
      # @return [Boolean]
      def logical_operator?
        operator_type == :logical
      end

      # Single source of truth for what binary operators exist and how they
      # render / classify. Adding a new operator here fills both call sites.
      OPERATOR_META = {
        and: { str: '&&', type: :logical },
        or: { str: '||', type: :logical },
        equal: { str: '==', type: :comparison },
        not_equal: { str: '!=', type: :comparison },
        less_than: { str: '<', type: :comparison },
        less_than_or_equal: { str: '<=', type: :comparison },
        greater_than: { str: '>', type: :comparison },
        greater_than_or_equal: { str: '>=', type: :comparison },
      }.freeze

      private

      def operator_meta
        OPERATOR_META.fetch(name) { raise "unknown binary operator #{name}" }
      end

      def operator_to_s
        operator_meta[:str]
      end

      def operator_type
        operator_meta[:type]
      end

      # Per-side checks that apply to either operand of a comparison.
      def validate_side(expr)
        return unless comparison_operator?

        unless expr.literal? || expr.singular_query?
          raise Error, "Expression #{expr} does not produce a singular value for #{operator_to_s} comparison"
        end
        if expr.is_a?(AST::Function) && !expr.literal?
          raise Error,
                "Function #{expr} returns a non-comparable value which is not usable for #{operator_to_s} comparison"
        end
      end

      # Checks that need both sides in scope.
      def validate_pair
        return unless @left.is_a?(Boolean) && @right.is_a?(Boolean)

        # Compliance test suite requires error for this, but don't go so far as to bar every literal.
        raise Error,
              "Literal \"#{@right}\" must be compared to an expression, not another literal (\"#{@left}\")"
      end
    end
  end
end
