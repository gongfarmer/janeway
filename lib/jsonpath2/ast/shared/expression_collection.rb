# frozen_string_literal: true

module JsonPath2
  module AST
    module Shared
      module ExpressionCollection
        class_exec do
          attr_accessor :expressions
        end

        def initialize
          @expressions = []
        end

        def <<(expr)
          expressions << expr
        end

        def ==(other)
          expressions == other&.expressions
        end

        def name
          string_underscore(self.class.to_s.split('::').last)
        end

        def string_underscore(string)
          string
            .gsub('::', '/')
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .tr('-', '_')
            .downcase
        end

        def children
          expressions
        end
      end
    end
  end
end
