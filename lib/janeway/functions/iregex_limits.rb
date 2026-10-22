# frozen_string_literal: true

require_relative '../error'

module Janeway
  module Functions
    # Limits on the I-Regexp that match() and search() accept.
    #
    # RFC 9485 section 8 names range quantifiers as the part of I-Regexp that regexp engines
    # struggle with, and lets an implementation limit their range and composability.
    # This rejects an I-Regexp that is very long, has a range quantifier with a large bound,
    # or applies a range quantifier to a group that contains another range quantifier.
    # @see https://www.rfc-editor.org/rfc/rfc9485.html#name-security-considerations
    class IRegexLimits
      # Longest I-Regexp that is accepted
      MAX_LENGTH = 10_000

      # Largest bound of a range quantifier such as a{2,4} that is accepted
      MAX_RANGE_QUANTIFIER_BOUND = 1_000

      # @param iregex [String]
      def initialize(iregex)
        @iregex = iregex
        @groups = [] # one entry per open group: does it contain a range quantifier?
        @closed_group_has_range = false
        @in_char_class = false
      end

      # @raise [Janeway::Error] when the I-Regexp exceeds a limit
      def check
        raise Error, "regexp is longer than #{MAX_LENGTH} characters" if @iregex.length > MAX_LENGTH

        index = 0
        index = check_char(index) while index < @iregex.length
      end

      private

      # @param index [Integer] index of the char to check
      # @return [Integer] index of the next char to check
      def check_char(index)
        char = @iregex[index]
        return index + 2 if char == '\\' # skip the escaped char

        if @in_char_class
          @in_char_class = false if char == ']'
        else
          case char
          when '[' then @in_char_class = true
          when '(' then open_group
          when ')' then return close_group(index)
          when '{' then index = check_range_quantifier(index)
          end
        end
        @closed_group_has_range = false
        index + 1
      end

      def open_group
        @groups.push(false)
      end

      # @return [Integer] index of the next char to check
      def close_group(index)
        @closed_group_has_range = @groups.pop || false
        @groups[-1] ||= @closed_group_has_range unless @groups.empty?
        index + 1
      end

      # @param index [Integer] index of the opening brace
      # @return [Integer] index of the closing brace
      def check_range_quantifier(index)
        close = @iregex.index('}', index)
        return @iregex.length unless close # not a range quantifier, Regexp.new decides what it is

        raise Error, 'nested range quantifiers are not supported' if @closed_group_has_range

        @iregex[(index + 1)...close].split(',').each do |bound|
          next if bound.to_i <= MAX_RANGE_QUANTIFIER_BOUND

          raise Error, "range quantifier bound #{bound} is larger than #{MAX_RANGE_QUANTIFIER_BOUND}"
        end
        @groups[-1] = true unless @groups.empty?
        close
      end
    end
  end
end
