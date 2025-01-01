# frozen_string_literal: true

module JsonPath2
  module AST
    # Represents a JSONPath built-in function.
    class Function < JsonPath2::AST::Expression
      alias name value

      attr_reader :parameters, :body

      # FIXME: provide function body too as a proc?
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
    end
  end
end
