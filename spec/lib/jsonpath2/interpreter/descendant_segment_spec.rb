# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    describe '#interpret_array_slice_selector' do
      let(:input) { ('a'..'g').to_a }

      # CTS "basic, descendant segment, wildcard selector, nested arrays",
      # rubocop: disable RSpec/ExampleLength
      it 'can be followed by wildcard selector' do
        input = [[[1]], [2]]
        expected =
          [
            [
              [
                1,
              ],
            ],
            [
              2,
            ],
            [
              1,
            ],
            1,
            2,
          ]
        expect(described_class.interpret(input, '$..[*]')).to match_array(expected)
      end
      # rubocop: enable RSpec/ExampleLength
    end
  end
end
