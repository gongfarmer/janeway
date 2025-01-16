# frozen_string_literal: true

require 'janeway'
require_relative 'selector'

module Janeway
  module AST
    # An index selector, e.g. 3, selects an indexed child of an array
    # @example: $.store.book[2].title
    class IndexSelector < Janeway::AST::Selector
      def initialize(index)
        raise Error, "Invalid value for index selector: #{index.inspect}" unless index.is_a?(Integer)
        raise Error, "Index selector value too small: #{index.inspect}" if index < INTEGER_MIN
        raise Error, "Index selector value too large: #{index.inspect}" if index > INTEGER_MAX

        super
      end

      # @param brackets [Boolean] include brackets around selector
      def to_s(brackets: true, **_ignored)
        brackets ? "[#{@value}]#{@next}" : "#{@value}#{@next}"
      end
    end
  end
end
