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

      def initialize(start = nil, end_ = nil, step = nil)
        super(nil)
        @start = start&.literal
        @end = end_&.literal

        # The default value for step is 1. The default values for start and end depend on the sign of step,
        @step = step ? step.literal.to_i : 1
        if @step >= 0
          @start ||= 0
          @end ||= -1
        else
          @start ||= -1 # len - 1
          @end ||= -1 # -len - 1 FIXME
        end
        # FIXME: check for invalid conditions.
        # eg. 0 start? end < start with positive step? ...
      end

      def inspect
        format('#<JsonPath2::AST::ArraySliceSelector:%s start=%s, end=%s, step=%s>',
          object_id, @start, @end, @step)
      end
    end
  end
end
