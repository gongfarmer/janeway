# frozen_string_literal: true

require_relative 'selector'

module JsonPath2
  module AST
    # An array slice start:end:step ({{slice}}) selects a series of elements from
    # an array, giving a start position, an end position, and an optional step
    # value that moves the position from the start to the end.
    #
    # @example
    #   $[1:3]
    #   $[5:]
    #   $[1:5:2]
    #   $[5:1:-2]
    #   $[::-1]
    class ArraySliceSelector < JsonPath2::AST::Selector
      attr_accessor :start, :end, :step

      # @param start [Token]
      # @param end_ [Token]
      # @param step [Token]
      def initialize(start = nil, end_ = nil, step = nil)
        super(nil)
        @start = normalize_arg(start)
        @end = normalize_arg(end_)

        # The default value for step is 1. The default values for start and end depend on the sign of step,
        @step = normalize_arg(step, 1)
        if @step >= 0
          @start ||= 0
          @end ||= -1
        else
          @start ||= -1 # len - 1
          @end ||= 0 # -len - 1 FIXME
        end
        # FIXME: check for invalid conditions.
        # eg. 0 start? end < start with positive step? ...
      end

      # Normalize argument to an integer by extracting literal value from token.
      # Return nil if given nil.
      # @param arg [Token, Integer]
      # @return [Integer]
      def normalize_arg(arg, default = nil)
        case arg
        when Integer then return arg
        when nil then return default
        end
        raise ArgumentError, "Expect token, got #{arg.inspect}" unless arg.is_a?(Token)

        raise "Expect token type :number, got #{arg.inspect}" unless arg.type == :number

        arg.literal
      end

      def to_s
        [@start, @end, @step].map(&:to_s).join(':')
      end

      # Get lower and upper array indexes for a particular array
      # @param len [Integer] input array size
      def get_bounds(len)
        bounds(@start, @end, @step, len)
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
        return index if index.positive?

        len + index
      end

      # IETF: Slice expression parameters start and end are used to derive
      # slice bounds lower and upper. The direction of the iteration, defined
      # by the sign of step, determines which of the parameters is the lower
      # bound and which is the upper bound:¶
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.4.2.2-9
      def bounds(start, end_, step, len)
        n_start = normalize(start, len)
        n_end = normalize(end_, len)

        if step >= 0
          lower = n_start.clamp(0, len)
          upper = n_end.clamp(0, len)
        else
          lower = n_start.clamp(-1, len - 1)
          upper = n_end.clamp(-1, len - 1)
        end

        [lower, upper]
      end

      def ==(other)
        self.class == other.class &&
          @start == other.start &&
          @end == other.end &&
          @step == other.step
      end

      # @param level [Integer]
      # @return [Array]
      def tree(level)
        [indented(level, to_s)]
      end
    end
  end
end
