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
        expect(result).to match_array([5, 4, 6])
      end
    end
  end
end
