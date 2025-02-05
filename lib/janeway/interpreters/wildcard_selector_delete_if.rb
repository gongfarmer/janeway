# frozen_string_literal: true

require_relative 'wildcard_selector_interpreter'
require_relative 'iteration_helper'

module Janeway
  module Interpreters
    # Interprets a wildcard selector by deleting array / hash values for which a block returns true.
    class WildcardSelectorDeleteIf < WildcardSelectorInterpreter
      include IterationHelper

      # @param selector [AST::WildcardSelector]
      def initialize(selector, &block)
        super(selector)
        @block = block

        # Make a proc that yields the correct number of values to a block
        @yield_proc = make_yield_proc(&block)
      end

      # Delete all elements from the input
      #
      # @param input [Array, Hash] the results of processing so far
      # @param _parent [Array, Hash] parent of the input object
      # @param _root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array] deleted elements
      def interpret(input, _parent, _root, path)
        case input
        when Array then maybe_delete_array_values(input, path)
        when Hash then maybe_delete_hash_values(input, path)
        else []
        end
      end

      # @param input [Array]
      # @param path [Array]
      def maybe_delete_array_values(input, path)
        results = []
        (input.size - 1).downto(0).each do |i|
          next unless @yield_proc.yield(input[i], input, path + [i])

          results << input.delete_at(i)
        end
        results.reverse
      end

      # @param input [Hash]
      # @param path [Array]
      def maybe_delete_hash_values(input, path)
        results = []
        input.each do |key, value|
          next unless @yield_proc.yield(value, input, path + [key])

          results << input.delete(key)
        end
        results
      end
    end
  end
end
