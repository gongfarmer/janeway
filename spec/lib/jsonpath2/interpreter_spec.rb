# frozen_string_literal: true

require 'jsonpath2'

# CTS = test from the "Compliance Test Suite"

module JsonPath2
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
      expect do
        described_class.interpret(input, '$[]')
      end.to raise_error(JsonPath2::Parser::Error, 'Empty child segment')
    end

    # FIXME: How? wildcard sends an array, name selector only operates on a hash.
    # CTS "basic, wildcard shorthand, then name shorthand",
    xit 'interprets wildcard shorthand then name shorthand' do
      input = {
        'x' => { 'a' => 'Ax', 'b' => 'Bx' },
        'y' => { 'a' => 'Ay', 'b' => 'By' },
      }
      expect(described_class.interpret(input, '$.*.a')).to eq(%w[Ax Ay])
    end

    it 'interprets null' do
      expect(described_class.interpret({}, '$[?@.a==null]')).to eq([])
    end

    it 'interprets filter expression with unary operator' do
      input = [{ 'a' => 'a', 'd' => 'e' }, { 'a' => 'b', 'd' => 'f' }, { 'a' => 'd', 'd' => 'f' }]
      query = "$[?!(@.a=='b')]"
      expected = [
        { 'a' => 'a', 'd' => 'e' },
        { 'a' => 'd', 'd' => 'f' },
      ]
      expect(described_class.interpret(input, query)).to eq(expected)
    end
  end
end
