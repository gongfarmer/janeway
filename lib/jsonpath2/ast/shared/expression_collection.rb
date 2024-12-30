# frozen_string_literal: true

require_relative '../helpers'

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
          AST::Helpers.camcelcase_to_underscore(self.class.to_s.split('::').last)
        end

        def children
          expressions
        end
      end
    end
  end
end
