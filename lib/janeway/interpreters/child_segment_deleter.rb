# frozen_string_literal: true

require_relative 'child_segment_interpreter'

module Janeway
  module Interpreters
    # Child segment interpreter with selectors that delete matching elements
    class ChildSegmentDeleter < ChildSegmentInterpreter 
      # @param child_segment [AST::ChildSegment]
      def initialize(child_segment)
        super
        @selectors =
          child_segment.map do |expr|
            TreeConstructor.ast_node_to_deleter(expr)
          end
      end
    end
  end
end
