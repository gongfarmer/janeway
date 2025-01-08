# frozen_string_literal: true

module JsonPath2
  module AST
    module Helpers
      # @param str [String] ascii string, CamelCase
      # @return [String] lowercase, with underscores
      def self.camelcase_to_underscore(str)
        found_uppercase = false
        chars = []
        str.each_char do |char|
          if char.ord.between?(65, 90) # ascii 'A'..'Z' inclusive
            chars << '_'
            chars << (char.ord + 32).chr
            found_uppercase = true
          else
            chars << char
          end
        end
        return str unless found_uppercase

        chars.shift if chars.first == '_'
        chars.join
      end
    end
  end
end
