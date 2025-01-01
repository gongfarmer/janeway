# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # A name selector, e.g. 'name', selects a named child of an object.
    # @example
    #   $.store
    #   $[store]
    # The dot or bracket part is not captured here, only the name
    class NameSelector < JsonPath2::AST::Selector
      alias name value
      attr_reader :children

      def initialize(value)
        super
        # FIXME: implement name matching requirements here
        raise "Invalid name: #{value.inspect}:#{value.class}" unless value.is_a?(String)

        @children = []
      end

      # Add a child expression which filters the results of this name selector
      def <<(expression)
        @children << expression
      end

      def to_s
        # Add quotes if the name includes chars that require quoting.
        # These chars are not allowed in dotted notation, only bracket notation.
        special_chars = [' ', '.']
        name_str =
          if special_chars.any? { |char| @value.include?(char) }
            quote(@value)
          else
            @value
          end
        "#{name_str}#{@children.map(&:to_s).join}"
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
    end
  end
end
