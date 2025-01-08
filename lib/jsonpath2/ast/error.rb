# frozen_string_literal: true

require_relative '../error'

module JsonPath2
  module AST
    # Error raised during parsing, for use by AST classes
    class Error < JsonPath2::Error; end
  end
end
