# frozen_string_literal: true

require 'janeway'

# CTS = test from the "Compliance Test Suite"

module Janeway
  describe Interpreter do
    let(:interpreter) { described_class.new({}) }

    it 'returns input when query is just a root selector' do
      input = { 'a' => 1 }
      expect(described_class.interpret(input, '$')).to eq([input])
    end

    # Compliance test suite requires this to raise a parse error
    # JsonPath comparison project suggests not to do that
    # CTS "basic, empty segment"
    it 'raises error for empty child segment' do
      input = { 'a' => 1 }
      expect {
        described_class.interpret(input, '$[]')
      }.to raise_error(Janeway::Error, /Empty child segment/)
    end

    # CTS "basic, wildcard shorthand, then name shorthand",
    it 'interprets wildcard shorthand then name shorthand' do
      input = {
        'x' => { 'a' => 'Ax', 'b' => 'Bx' },
        'y' => { 'a' => 'Ay', 'b' => 'By' },
      }
      expect(described_class.interpret(input, '$.*.a')).to match_array(%w[Ax Ay])
    end

    it 'interprets null' do
      expect(described_class.interpret({}, '$[?@.a==null]')).to eq([])
    end

    # CTS "filter, not expression",
    it 'interprets filter expression with unary operator' do
      input = [{ 'a' => 'a', 'd' => 'e' }, { 'a' => 'b', 'd' => 'f' }, { 'a' => 'd', 'd' => 'f' }]
      query = "$[?!(@.a=='b')]"
      expected = [{ 'a' => 'a', 'd' => 'e' }, { 'a' => 'd', 'd' => 'f' }]
      expect(described_class.interpret(input, query)).to eq(expected)
    end

    # RFC
    it 'parses wildcard selector with brackets in between name selectors with shorthand notation' do
      input = { 'a' => [{ 'b' => 0 }, { 'b' => 1 }, { 'c' => 2 }] }
      query = '$.a[*].b'
      expect(described_class.interpret(input, query)).to eq([0, 1])
    end
  end
end
