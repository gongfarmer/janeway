# frozen_string_literal: true

require_relative 'expression'

module Janeway
  module AST
    # Represents a JSONPath built-in function.
    class Function < Janeway::AST::Expression
      alias name value

      attr_reader :parameters, :body

      def initialize(name, parameters, &body)
        raise ArgumentError, "expect string, got #{name.inspect}" unless name.is_a?(String)

        super(name)
        @parameters = parameters
        @body = body
        raise "expect body to be a Proc, got #{body.class}" unless body.is_a?(Proc)
      end

      def to_s
        "#{name}(#{@parameters.join(',')})"
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end

      # True if this is the root of a singular-query.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-well-typedness-of-function-
      #
      # @return [Boolean]
      def singular_query?
        true
      end

      # True if the function's return value is a literal
      def literal?
        case name
        when 'length', 'count', 'value' then true
        when 'search', 'match' then false
        else
          raise "Unknown jsonpath function #{name}"
        end
      end
    end
  end
end
