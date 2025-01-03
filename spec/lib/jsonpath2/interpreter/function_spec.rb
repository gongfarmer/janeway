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

      describe 'jsonpath function "match"' do
        it 'supports regular expression match of array values' do
          # entire string match
          result = described_class.interpret(input, '$.a[?match(@.b, "[jk]")]')
          expect(result).to eq([{ 'b' => 'j' }, { 'b' => 'k' }])
        end

        it 'reads iregexp from the input document' do
          query = '$.values[?match(@, $.regex)]'
          input =
            {
              'regex' => 'b.?b',
              'values' => ['abc', 'bcd', 'bab', 'bba', 'bbab', 'b', true, [], {}]
            }
          expected = ['bab']
          expect(described_class.interpret(input, query)).to eq(expected)
        end
      end

      describe 'jsonpath function "match"' do
        it 'supports regular expression search of array values' do
          # substring match
          result = described_class.interpret(input, '$.a[?search(@.b, "[jk]")]')
          expect(result).to eq([{ 'b' => 'j' }, { 'b' => 'k' }, { 'b' => 'kilo' }])
        end
      end

      it 'interprets the value() function' do
        query = '$[?value(@.*)==4]'
        input = [[4], { 'foo' => 4 }, [5], { 'foo' => 5 }, 4]
        expected = [[4], { 'foo' => 4 }]
        expect(described_class.interpret(input, query)).to eq(expected)
      end

      it 'interprets usage of the root node in a function call' do
        query = '$.values[?length(@.a) == value($..c)]'
        input =
          {
            'c' => 'cd',
            'values' => [
              {'a' => 'ab'},
              {'c' => 'd'},
              {'a' => nil}
            ]
          }
        expected = [{'c' => 'd'}, {'a' => nil}]
        expect(described_class.interpret(input, query)).to eq(expected)
      end
    end
  end
end
