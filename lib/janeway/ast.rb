# frozen_string_literal: true

module Janeway
  # Abstract Syntax Tree
  module AST
    # These are the limits of what javascript's Number type can represent
    INTEGER_MIN = -9_007_199_254_740_991
    INTEGER_MAX = 9_007_199_254_740_991
  end
end

require_relative 'ast/array_slice_selector'
require_relative 'ast/binary_operator'
require_relative 'ast/boolean'
require_relative 'ast/child_segment'
require_relative 'ast/current_node'
require_relative 'ast/descendant_segment'
require_relative 'ast/error'
require_relative 'ast/expression'
require_relative 'ast/filter_selector'
require_relative 'ast/function'
require_relative 'ast/helpers'
require_relative 'ast/index_selector'
require_relative 'ast/name_selector'
require_relative 'ast/null'
require_relative 'ast/number'
require_relative 'ast/root_node'
require_relative 'ast/selector'
require_relative 'ast/string_type'
require_relative 'ast/unary_operator'
require_relative 'ast/wildcard_selector'
