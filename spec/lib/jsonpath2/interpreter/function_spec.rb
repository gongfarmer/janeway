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
            "e": "abcdef"
          }
        JSON_STRING
      end

      describe 'jsonpath function "length"' do
        it 'gets the length of a string' do
          input = %w[a ab abc abcd]
          expect(described_class.interpret(input, '$[? length(@) == 3]')).to eq(['abc'])
        end

        it 'gets the number of elements in an array' do
          input = [
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4],
            [1, 2, 3],
          ]
          expect(described_class.interpret(input, '$[?(length(@) == 4)]')).to eq([[1, 2, 3, 4]])
        end

        it 'gets the number of members in a hash' do
          input = [
            { a: 1 },
            { a: 1, b: 2 },
            { a: 1, b: 2, c: 3 },
          ]
          expect(described_class.interpret(input, '$[?(length(@) == 2)]')).to eq([{ a: 1, b: 2 }])
        end

        it 'returns Nothing if the input is not a string, array or hash' do
          input = [1, 2, 3]
          expect(described_class.interpret(input, '$[? length(@) == 3]')).to eq([])
        end
      end

      describe 'jsonpath function "count"' do
        it 'returns 1 when applied to any string' do
          input = %w[a ab abc abcd]
          expect(described_class.interpret(input, '$[? count(@) == 1]')).to eq(input)
        end

        it 'gets the number of elements in an array' do
          input = [
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4],
            [1, 2, 3],
          ]
          expect(described_class.interpret(input, '$[?(count(@) == 4)]')).to eq([[1, 2, 3, 4]])
        end

        it 'returns 1 when applied to any hash' do
          input = [
            { a: 1 },
            { a: 1, b: 2 },
            { a: 1, b: 2, c: 3 },
          ]
          expect(described_class.interpret(input, '$[?(count(@) == 1)]')).to eq(input)
        end
      end

      it 'supports regular expression match of array values' do
        # entire string match
        result = described_class.interpret(input, '$.a[?match(@.b, "[jk]")]')
        expect(result).to eq([{ 'b' => 'j' }, { 'b' => 'k' }])
      end

      it 'supports regular expression search of array values' do
        # substring match
        result = described_class.interpret(input, '$.a[?search(@.b, "[jk]")]')
        expect(result).to eq([{ 'b' => 'j' }, { 'b' => 'k' }, { 'b' => 'kilo' }])
      end
    end
  end
end
