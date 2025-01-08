# frozen_string_literal: true

require_relative 'helpers'
require_relative 'error'

module JsonPath2
  module AST
    INDENT = '  '

    class Expression
      attr_accessor :value

      def initialize(val = nil)
        # don't set the instance variable if unused, because it makes the
        # "#inspect" output cleaner in rspec test failures
        @value = val unless val.nil?  # false must be stored though!
      end

      def ==(other)
        raise NotImplementedError # subclass must implement
      end

      # @return [String]
      def type
        name = self.class.to_s.split('::').last # eg. JsonPath2::AST::FunctionCall => "FunctionCall"
        Helpers.camelcase_to_underscore(name) # eg. "FunctionCall" => "function_call"
      end

      # Return the given message, indented
      #
      # @param level [Integer]
      # @param msg [String]
      # @return [String]
      def indented(level, msg)
        format('%s%s', (INDENT * level), msg)
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
    end
  end
end
