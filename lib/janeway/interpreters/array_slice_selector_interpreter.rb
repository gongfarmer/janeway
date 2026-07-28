# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # Interprets array slice selector on the given input
    class ArraySliceSelectorInterpreter < Base
      alias selector node

      # Filter the input by applying the array slice selector.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array]
      def interpret(input, _parent, root, path)
        return [] unless input.is_a?(Array)
        return [] if effective_step.zero? # RFC: When step is 0, no elements are selected.

        indexes = index_range(input.size)
        return indexes.map { |i| input[i] } unless @next

        # Apply child selector to each node in the output node list
        results = []
        indexes.each do |i|
          results.concat @next.interpret(input[i], input, root, path + [i])
        end
        results
      end

      # @return [Hash]
      def as_json
        { type: type, value: node.to_s, next: @next&.as_json }.compact
      end

      protected

      # Concrete list of source-array indexes this slice selects, in
      # iteration order. Consumed by both this interpreter and
      # ArraySliceSelectorDeleteIf.
      #
      # @param input_size [Integer]
      # @return [Array<Integer>]
      def index_range(input_size)
        lower, upper = bounds(input_size)
        if effective_step.positive?
          lower.step(to: upper - 1, by: effective_step).to_a
        else
          upper.step(to: lower + 1, by: effective_step).to_a
        end
      end

      # Effective step: raw @step from the AST, or 1 if unspecified.
      def effective_step
        selector.step || 1
      end

      # Compute lower/upper bounds for the slice given the input array size.
      # RFC 9535 pseudocode lives here (formerly on AST::ArraySliceSelector).
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.4.2.2
      #
      # @param input_size [Integer]
      # @return [Array(Integer, Integer)] [lower, upper]
      def bounds(input_size)
        if effective_step >= 0
          start = selector.start || 0
          end_ = selector.end || input_size
        else
          start = selector.start || (input_size - 1)
          end_ = selector.end || ((-1 * input_size) - 1)
        end

        n_start = normalize(start, input_size)
        n_end = normalize(end_, input_size)

        if effective_step >= 0
          [n_start.clamp(0, input_size), n_end.clamp(0, input_size)]
        else
          [n_end.clamp(-1, input_size - 1), n_start.clamp(-1, input_size - 1)]
        end
      end

      # IETF: slice parameters must be normalized before use as bounds —
      # negative values count from the end of the array.
      def normalize(index, len)
        index >= 0 ? index : len + index
      end
    end
  end
end
