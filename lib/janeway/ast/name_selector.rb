# frozen_string_literal: true

require_relative 'selector'

module Janeway
  module AST
    # A name selector, e.g. 'name', selects a named child of an object.
    # @example
    #   $.store
    #   $[store]
    # The dot or bracket part is not captured here, only the name
    class NameSelector < Janeway::AST::Selector
      alias name value

      def initialize(value)
        super
        raise "Invalid name: #{value.inspect}:#{value.class}" unless value.is_a?(String)
      end

      # Chars that force bracket notation (they are not permitted in the
      # dotted shorthand).
      SPECIAL_CHARS = /[ .]/

      # @param brackets [Boolean] request for bracket syntax
      # @param dot_prefix [Boolean] include . prefix, if shorthand notation is used
      # @param bracketed [Boolean] caller already provided brackets (e.g. within a union);
      #   emit the quoted name only, without adding brackets
      def to_s(brackets: false, dot_prefix: true, bracketed: false)
        # Add quotes and surrounding brackets if the name includes chars that require quoting.
        brackets ||= @value.match?(SPECIAL_CHARS)
        if bracketed
          "#{quote(@value)}#{@next}"
        elsif brackets
          "[#{quote(@value)}]#{@next}"
        elsif dot_prefix
          ".#{@value}#{@next}"
        else # omit dot prefix after a descendant segment
          "#{@value}#{@next}"
        end
      end

      # put surrounding quotes on a string
      # @return [String]
      def quote(str)
        if str.include?("'")
          format('"%s"', str)
        else
          "'#{str}'"
        end
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, "NameSelector:\"#{@value}\""), @next&.tree(level + 1)]
      end
    end
  end
end
