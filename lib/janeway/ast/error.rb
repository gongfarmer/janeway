# frozen_string_literal: true

require_relative '../error'

module Janeway
  module AST
    # Error raised during parsing, for use by AST classes
    class Error < Janeway::Error; end
  end
end
