# frozen_string_literal: true

require 'jsonpath2'
require 'json'

# https://www.rfc-editor.org/rfc/rfc9535.html#name-wildcard-selector

module JsonPath2
  describe Interpreter do
    let(:input) do
      JSON.parse(<<~JSON_STRING)
        {
          "o": {"j": 1, "k": 2},
          "a": [5, 3]
        }
      JSON_STRING
    end

    it 'selects values, and excludes keys when applied to root node' do
      expected = [input['o'], input['a']]
      expect(described_class.interpret(input, '$[*]')).to eq(expected)
    end

    it 'uses shorthand notation' do
      input = { 'a' => 'A', 'b' => 'B' }
      expected = ["A", "B"]
      expect(described_class.interpret(input, '$.*')).to match_array(expected)
    end

    it 'selects values when applied to a hash' do
      expected = [1, 2] # order is not deterministic
      expect(described_class.interpret(input, '$.o[*]')).to match_array(expected)
    end

    it 'selects values when applied to an array' do
      expected = [5, 3] # order is not deterministic
      expect(described_class.interpret(input, '$.a[*]')).to match_array(expected)
    end

    it 'may be used in a comma-separated list' do
      expected = [1, 2, 2, 1] # order is not deterministic
      expect(described_class.interpret(input, '$.o[*, *]')).to match_array(expected)
    end
  end
end
