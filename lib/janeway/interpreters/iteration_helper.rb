# frozen_string_literal: true

require_relative '../normalized_path'

module Janeway
  module Interpreters
    # Mixin for interpreter classes that yield to a block
    module IterationHelper
      # Returns a Proc that yields the correct number of parameters to a block
      #
      # block.arity is -1 when no block is given, and an enumerator is being returned
      # @return [Proc] which takes 3 parameters
      def make_yield_proc(&block)
        if block.arity.negative?
          # Yield just the value to an enumerator, to enable instance method calls on
          # matched values like this: enum.delete_if(&:even?)
          proc { |value, _parent, _path| @block.call(value) }
        elsif block.arity > 3
          # Only do the work of constructing the normalized path when it is actually used
          proc { |value, parent, path| @block.call(value, parent, path.last, normalized_path(path)) }
        else
          # block arity is 1, 2 or 3. Send all 3 parameters regardless.
          proc { |value, parent, path| @block.call(value, parent, path.last) }
        end
      end

      # Convert the list of path elements into a normalized query string.
      #
      # This form uses a subset of jsonpath that unambiguously points to a value
      # using only name and index selectors.
      # @see https://www.rfc-editor.org/rfc/rfc9535.html#name-normalized-paths
      #
      # Name selectors must use bracket notation, not shorthand.
      #
      # @param components [Array<String, Integer>]
      # @return [String]
      def normalized_path(components)
        # First component is the root identifer, the remaining components are
        # all index selectors or name selectors.
        # Handle the root identifier separately, because .normalize does not handle those.
        '$' + components[1..].map { NormalizedPath.normalize(_1) }.join
      end
    end
  end
end
