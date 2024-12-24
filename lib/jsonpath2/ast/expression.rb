# frozen_string_literal: true

module JsonPath2
  module AST
    class Expression
      attr_accessor :value

      def initialize(val = nil)
        @value = val
      end

      def ==(other)
        raise NotImplementedError # subclass must implement
      end

      def children
        []
      end

      # @return [String]
      def type
        name = self.class.to_s.split('::').last # eg. JsonPath2::AST::FunctionCall => "FunctionCall"
        camelcase_to_underscore(name) # eg. "FunctionCall" => "function_call"
      end

      # @param str [String] ascii string
      def camelcase_to_underscore(str)
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
