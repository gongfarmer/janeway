# frozen_string_literal: true

module JsonPath2
  module Error
    module Runtime
      class UnexpectedReturn < StandardError
        def initialize
          super('Unexpected return')
        end
      end
    end
  end
end
