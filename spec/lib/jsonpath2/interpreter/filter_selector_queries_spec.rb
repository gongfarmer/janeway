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

      it 'does existence check using only the current_node operator' do
        input = {"a"=>1, "b"=>nil}
        expect(described_class.interpret(input, '$[?@]')).to match_array([1, nil])
      end

      it 'tests for null values and returns the matches' do
        input = [{"a"=>nil, "d"=>"e"}, {"b"=>"c", "d"=>"f"}]
        expected = [{"a"=>nil, "d"=>"e"}]
        expect(described_class.interpret(input, '$[?@.a]')).to match_array(expected)
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

      it 'supports union of two filter selectors' do
        result = described_class.interpret(input, '$.o[?@<3, ?@<3]')
        expect(result).to match_array([1, 2, 2, 1]) # order is undefined
      end

      it 'supports multiple union operators' do
        result = described_class.interpret(input, '$.o[?@<3, ?@<3, ?@<3]')
        expect(result).to match_array([1, 2, 1, 2, 1, 2]) # order is undefined
      end

      it 'supports logical OR of array values' do
        result = described_class.interpret(input, '$.a[?@<2 || @.b == "k"]')
        expect(result).to eq([1, { 'b' => 'k' }])
      end

      it 'supports logical AND of object values' do
        result = described_class.interpret(input, '$.o[?@>1 && @<4]')
        expect(result).to eq([2, 3]) # order is undefined
      end

      it 'supports logical OR of object values' do
        result = described_class.interpret(input, '$.o[?@.u || @.x]')
        expect(result).to eq([{ 'u' => 6 }]) # order is undefined
      end

      it 'supports comparison of queries with no values' do
        result = described_class.interpret(input, '$.a[?@.b == $.x]')
        expect(result).to eq([3,5,1,2,4,6]) # order is undefined
      end

      it 'compares primitive and structured values' do
        result = described_class.interpret(input, '$.a[?@ == @]')
        expect(result).to eq(
          [
            3, 5, 1, 2, 4, 6,
            { 'b' => 'j' },
            { 'b' => 'k' },
            { 'b' => {} },
            { 'b' => 'kilo' },
          ]
        )
      end

      it 'does comparison of null with key that has null value' do
        input = [{"a"=>nil, "d"=>"e"}, {"a"=>"c", "d"=>"f"}]
        result = described_class.interpret(input, '$[?@.a==null]')
        expect(result).to eq([{"a"=>nil, "d"=>"e"}])
      end

      it 'does comparison of false with key that has false value' do
        input = [{"a"=>false, "d"=>"e"}, {"a"=>"c", "d"=>"f"}]
        result = described_class.interpret(input, '$[?@.a==false]')
        expect(result).to eq([{"a"=>false, "d"=>"e"}])
      end

      it 'uses correct precedence with logical and comparison operators' do
        input = [{"d"=>"e"}, {"a"=>"c", "d"=>"f"}]
        result = described_class.interpret(input, '$[?@.a&&@.a!=null]')
        expect(result).to eq([{"a"=>"c", "d"=>"f"}])
      end
    end
  end
end
