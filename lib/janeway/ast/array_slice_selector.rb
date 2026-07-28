# frozen_string_literal: true

require 'janeway'
require_relative 'selector'

module Janeway
  module AST
    # An array slice selects a series of elements from an array.
    #
    # It accepts a start and end positions, and a step value that define the range to select.
    # All of these are optional.
    #
    # @example
    #   $[1:3]
    #   $[5:]
    #   $[1:5:2]
    #   $[5:1:-2]
    #   $[::-1]
    #   $[:]
    #
    # ArraySliceSelector needs to store "default" arguments differently from
    # "explicit" arguments, since they're interpreted differently.
    #
    class ArraySliceSelector < Janeway::AST::Selector
      # Raw start / end / step values from the query source. Any of them may
      # be nil, meaning "use the default for the current step direction" —
      # the interpreter resolves that.
      attr_reader :start, :end, :step

      # @param start [Integer, nil]
      # @param end_ [Integer, nil]
      # @param step [Integer, nil]
      def initialize(start = nil, end_ = nil, step = nil)
        super(nil)

        # Check arguments
        [start, end_, step].each do |arg|
          unless [NilClass, Integer].include?(arg.class)
            raise Error, "Array slice selector index must be integer or nothing, got #{arg.inspect}"
          end
          next unless arg

          # Check integer size limits
          raise Error, "Array slice selector value too small: #{arg.inspect}" if arg < INTEGER_MIN
          raise Error, "Array slice selector value too large: #{arg.inspect}" if arg > INTEGER_MAX
        end

        # Nil values are kept to indicate that the default value should be used.
        # The interpreter selects the actual values.
        @start = start
        @end = end_
        @step = step
      end

      # @param brackets [Boolean] add surrounding brackets if true
      # @return [String]
      def to_s(brackets: true, **_ignored)
        index_str =
          if @step
            "#{@start}:#{@end}:#{@step}"
          else
            "#{@start}:#{@end}"
          end
        brackets ? "[#{index_str}]" : index_str
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end
    end
  end
end
