# frozen_string_literal: true

require 'json'
require 'jsonpath2'

# Examples from https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.5.3-8
module JsonPath2
  describe Interpreter do
    describe '#interpret_filter_selector' do
      let(:input) do
        JSON.parse(<<~JSON_STRING)
          {
            "a": [3, 5, 1, 2, 4, 6,
                  {"b": "j"},
                  {"b": "k"},
                  {"b": {}},
                  {"b": "kilo"}
                 ],
            "o": {"p": 1, "q": 2, "r": 3, "s": 5, "t": {"u": 6}},
            "e": "f"
          }
        JSON_STRING
      end

      it 'compares member value to string literal with ==' do
        result = described_class.interpret(input, "$.a[?@.b == 'kilo']")
        expect(result).to eq([{ 'b' => 'kilo' }])
      end

      it 'compares member value to string literal with ==, using enclosing parentheses' do
        result = described_class.interpret(input, "$.a[?(@.b == 'kilo')]")
        expect(result).to eq([{ 'b' => 'kilo' }])
      end

      it 'compares numerical array values' do
        result = described_class.interpret(input, '$.a[?@>3.5]')
        expect(result).to eq([5, 4, 6])
      end

      it 'tests array value existence' do
        result = described_class.interpret(input, '$.a[?@.b]')
        expect(result).to eq(
          [
            { 'b' => 'j' },
            { 'b' => 'k' },
            { 'b' => {} },
            { 'b' => 'kilo' },
          ]
        )
      end

      it 'does non-singular queries' do
        result = described_class.interpret(input, '$[?@.*]')
        expect(result).to eq(
          [
            [
              3, 5, 1, 2, 4, 6,
              { 'b' => 'j' },
              { 'b' => 'k' },
              { 'b' => {} },
              { 'b' => 'kilo' },
            ],
            { 'p' => 1, 'q' => 2, 'r' => 3, 's' => 5, 't' => { 'u' => 6 } },
          ]
        )
      end

      it 'supports nested filter selectors' do
        result = described_class.interpret(input, '$[?@[?@.b]]')
        expect(result).to eq(
          [[3, 5, 1, 2, 4, 6, { 'b' => 'j' }, { 'b' => 'k' }, { 'b' => {} }, { 'b' => 'kilo' }]]
        )
      end

      xit 'supports unioned filter selectors' do
        result = described_class.interpret(input, '$.o[?@<3, @<3]')
        expect(result).to eq([1, 2, 2, 1])
      end
    end
  end
end
