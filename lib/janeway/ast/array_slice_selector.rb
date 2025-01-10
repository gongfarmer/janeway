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
      def upper_index(input_size)
        calculate_index_values(input_size).last
      end

      # Return the end index to use for stepping through the array, based on a specified array size
      # End index is calculated to omit the final index value, as per the RFC.
      #
      # @param input_size [Integer]
      # @return [Integer]
      def lower_index(input_size)
        calculate_index_values(input_size).first
      end

      # Assign lower and upper bounds to instance variables, based on the input array size.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.4.2.2-3
      #
      # @param input_size [Integer]
      def calculate_index_values(input_size)
        if step >= 0
          start = @start || 0
          end_ = @end || input_size
        else
          start = @start || (input_size - 1)
          end_ = @end || ((-1 * input_size) - 1)
        end

        bounds(start, end_, step, input_size)
      end

      # NOTE: Conversion of start:end:step to array indexes is defined as pseudocode
      # in the IETF spec.
      # The methods #normalize and #bounds are ruby implementations of that code.
      # Don't make changes here without referring to the original code in the spec.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.4.2.2-6

      # IETF: Slice expression parameters start and end are not directly usable
      # as slice bounds and must first be normalized.
      #
      # @param index [Integer]
      # @param len [Integer]
      def normalize(index, len)
        return index if index >= 0

        len + index
      end

      # IETF: Slice expression parameters start and end are used to derive
      # slice bounds lower and upper. The direction of the iteration, defined
      # by the sign of step, determines which of the parameters is the lower
      # bound and which is the upper bound:¶
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.4.2.2-9
      # @param start [Integer] start index, normalized
      # @param end_ [Integer] end index, normalized
      # @param step [Integer] step value
      # @param len [Integer] length of input array
      def bounds(start, end_, step, len)
        n_start = normalize(start, len)
        n_end = normalize(end_, len)

        if step >= 0
          lower = n_start.clamp(0, len)
          upper = n_end.clamp(0, len)
        else
          upper = n_start.clamp(-1, len - 1)
          lower = n_end.clamp(-1, len - 1)
        end

        [lower, upper]
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
