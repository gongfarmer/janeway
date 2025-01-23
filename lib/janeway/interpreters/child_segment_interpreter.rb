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
        @nodes =
          child_segment.map do |expr|
            TreeConstructor.ast_node_to_interpreter(expr)
          end
      end

      # Interpret a set of 2 or more selectors, seperated by the union operator.
      # All selectors are sent the identical input, the results are combined.
      #
      # @param input [Array, Hash] the results of processing so far
      # @param root [Array, Hash] the entire input
      # @param path [Array<String>] elements of normalized path to the current input
      # @return [Array]
      def interpret(input, parent, root, path)
        # Apply each expression to the input, collect results
        results = []
        @nodes.each do |node|
          results.concat node.interpret(input, parent, root, path)
        end

        # Return results, or forward them to the next selector
        return results unless @next

        # FIXME: I have no idea how to implement pathing here. This does not seem correct
        @next.interpret(results, parent, root, path)
      end
    end
  end
end
