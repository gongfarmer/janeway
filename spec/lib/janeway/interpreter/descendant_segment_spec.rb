# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Interpreter do
    context 'when interpreting a descendant segment' do
      let(:input) { ('a'..'g').to_a }

      # CTS "basic, descendant segment, wildcard selector, nested arrays",
      # rubocop: disable RSpec/ExampleLength
      it 'can be followed by wildcard selector' do
        input = [[[1]], [2], 3]
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
            3,
          ]
        expect(described_class.interpret(input, '$..*')).to match_array(expected)
      end
      # rubocop: enable RSpec/ExampleLength

      it 'does not omit nil resuts from array' do
        input = [1, nil, 3]
        expected = [1, nil, 3]
        expect(described_class.interpret(input, '$..*')).to match_array(expected)
      end

      it 'does not omit nil resuts from hash' do
        input = { a: 1, b: nil, c: 3 }
        expected = [1, nil, 3]
        expect(described_class.interpret(input, '$..*')).to match_array(expected)
      end
    end
  end
end
