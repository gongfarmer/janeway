# frozen_string_literal: true

require_relative 'ast/function'

module JsonPath2
  # Mixin to provide JSONPath function handlers for Parser
  module Functions
  end
end

# Require function definitions
Dir.children("#{__dir__}/functions/").each do |path|
  require_relative "functions/#{path[0..-4]}"
end
