# frozen_string_literal: true

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
      # @param start [Integer, nil]
      # @param end_ [Integer, nil]
      # @param step [Integer, nil]
      def initialize(start = nil, end_ = nil, step = nil)
        [start, end_, step].each do |arg|
          next if arg.nil? || arg.is_a?(Integer)

          raise ArgumentError, "Expect Integer or nil, got #{arg.inspect}"
        end
        super(nil)

        # Nil values are kept to indicate that the "default" values is to be used.
        # The interpreter selects the actual values.
        @start = start
        @end = end_
        @step = step
      end

      # Return the step size to use for stepping through the array.
      # Defaults to 1 if it was not given to the constructor.
      #
      # @return [Integer]
      def step
        # The iteration behavior of jsonpath does not match that of ruby Integer#step.
        # Support the behavior of Integer#step, which needs this:
        #   1. for stepping forward between positive numbers, use a positive number
        #   2. for stepping backward between positive numbers, use a negative number
        #   3. for stepping backward from positive to negative, use a negative number
        #   4. for stepping backward from negative to negative, use a positive number
        # Case #4 has to be detected and the sign of step inverted
        @step || 1
      end

      # Return the start index to use for stepping through the array, based on a specified array size
      #
      # @param input_size [Integer]
      # @return [Integer]
      def start_index(input_size)
        if @start
          @start.clamp(0, input_size)
        elsif step.positive?
          0
        else # negative step
          input_size - 1 # last index of input
        end
      end

      # Return the end index to use for stepping through the array, based on a specified array size
      # End index is calculated to omit the final index value, as per the RFC.
      #
      # @param input_size [Integer]
      # @return [Integer]
      def end_index(input_size)
        if @end
          value = @end.clamp(0, input_size)
          step.positive? ? value - 1 : value + 1 # +/- to exclude the final element
        elsif step.positive?
          input_size - 1 # last index of input
        else
          0
        end
      end

      # ignores the brackets: argument, this always needs surrounding brackets
      # @return [String]
      def to_s(*)
        if @step
          "[#{@start}:#{@end}:#{@step}]"
        else
          "[#{@start}:#{@end}]"
        end
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end
    end
  end
end