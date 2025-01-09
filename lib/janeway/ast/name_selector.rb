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
        # FIXME: implement name matching requirements here
        raise "Invalid name: #{value.inspect}:#{value.class}" unless value.is_a?(String)
      end

      def to_s(brackets: false)
        # Add quotes and surrounding brackets if the name includes chars that require quoting.
        # These chars are not allowed in dotted notation, only bracket notation.
        special_chars = [' ', '.']
        brackets ||= special_chars.any? { |char| @value.include?(char) }
        name_str =
          if brackets
            quote(@value)
          else
            @value
          end
        brackets ? "[#{name_str}]#{@child}" : "#{name_str}#{@child}"
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
        [indented(level, "NameSelector:\"#{@value}\""), @child.tree(level + 1)]
      end
    end
  end
end
