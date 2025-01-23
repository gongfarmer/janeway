# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets the "not" operator within a filter selector logical expression.
    # The only other unary operator is "minus", which is consumed during parsing and is not part of the AST.
    class UnaryOperatorInterpreter < Base
      alias operator node

      def initialize(operator)
        super
        raise "Unknown unary operator: #{name}" unless operator.name == :not

        # Expression which must be evaluated, not operator will be applied to result
        @operand = TreeConstructor.ast_node_to_interpreter(operator.operand)
      end

      # @return [Boolean]
      def interpret(input, parent, root, _path)
        result = @operand.interpret(input, parent, root, [])
        case result
        when Array then result.empty?
        when TrueClass, FalseClass then !result
        else
          raise "don't know how to apply not operator to #{result.inspect}"
        end
      end
    end
  end
end
