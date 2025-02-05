# frozen_string_literal: true

require_relative 'child_segment_interpreter'

module Janeway
  module Interpreters
    # Child segment interpreter with selectors that delete matching elements if
    # the given block yields a truthy value
    class ChildSegmentDeleteIf < ChildSegmentInterpreter
      # @param child_segment [AST::ChildSegment]
      def initialize(child_segment, &block)
        super(child_segment)
        @selectors =
          child_segment.map do |expr|
            TreeConstructor.ast_node_to_delete_if(expr, &block)
          end
      end
    end
  end
end
