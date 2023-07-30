# frozen_string_literal: true

module JsonPath2
  module Error
    module Runtime
      class UndefinedVariable < StandardError
        def initialize(variable_name)
          super("Undefined variable #{variable_name}")
        end
      end
    end
  end
end
