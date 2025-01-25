# frozen_string_literal: true

require_relative 'base'

module Janeway
  module Interpreters
    # For each node in the input nodelist, the resulting nodelist of a child
    # segment is the concatenation of the nodelists from each of its
    # selectors in the order that the selectors appear in the list. Note: Any
    # node matched by more than one selector is kept as many times in the nodelist.
    #
    # A child segment can only contain selectors according to the RFC's ABNF grammar, so it
    # cannot contain another child segment, or a new expression starting with the root identifier.
    class ChildSegmentInterpreter < Base
      # @param child_segment [AST::ChildSegment]
      def initialize(child_segment)
        super
        @selectors =
          child_segment.map do |expr|
            TreeConstructor.ast_node_to_interpreter(expr)
          end
      end

      # Append an interpreter onto each of the selector branches
      # @param node [Interpreters::Base]
      def push(node)
        return unless node

        node.next = nil
        @selectors.each do |selector|
          last_node = find_last(selector)
          if last_node.is_a?(Interpreters::ChildSegmentInterpreter)
            last_node.push(node.dup)
          else
            last_node.next = node.dup
          end
        end
      end

      # Interpret a set of 2 or more selectors, seperated by the union operator.
      # All selectors are sent identical input, the results are combined.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param parent [Array, Hash] parent of the input object
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array]
      def interpret(input, parent, root, path)
        # Apply each expression to the input, collect results
        results = []
        @selectors.each do |selector|
          results.concat selector.interpret(input, parent, root, path)
        end

        results
      end

      # Return hash representation of this interpreter
      # @return [Hash]
      def as_json
        {
          type: type,
          selectors: @selectors.map(&:as_json),
          next: @next&.as_json,
        }
      end

      private

      # Find the last descendant of the given selector (ie. first one with no "next" selector)
      # @param selector [Interpreters::Base]
      # @return [Interpreters::Base]
      def find_last(selector)
        node = selector
        loop do
          break unless node.next

          node = node.next
        end
        node
      end
    end
  end
end
