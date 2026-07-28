# frozen_string_literal: true

require_relative 'expression'

module Janeway
  module AST
    # Represents a JSONPath built-in function.
    #
    # This is pure structure: name + parameters. The body / literal_return
    # metadata lives in Functions::REGISTRY (looked up by name), so AST nodes
    # don't drag closures over the parser's binding.
    class Function < Janeway::AST::Expression
      alias name value

      attr_reader :parameters

      def initialize(name, parameters)
        raise ArgumentError, "expect string, got #{name.inspect}" unless name.is_a?(String)

        spec = Functions::REGISTRY[name]
        raise ArgumentError, "unknown function #{name.inspect}" unless spec
        unless spec[:arity] == parameters.size
          raise ArgumentError,
                "function #{name.inspect}: declared arity #{spec[:arity]} does not " \
                "match parameter count #{parameters.size}"
        end

        super(name)
        @parameters = parameters
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
        Functions::REGISTRY.fetch(name)[:literal_return]
      end
    end
  end
end
