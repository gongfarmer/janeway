# frozen_string_literal: true

require 'janeway'

describe Janeway do
  describe '.each' do
    it 'yields one input value from a singular query' do
      input = { 'a' => { 'b' => { 'c' => 5 } } }
      seen = []
      described_class.each('$.a.b.c', input) do |value|
        seen << value
      end
      expect(seen).to eq([5])
    end

    it 'yields all values from a non-singular query' do
      input = { 'a' => %w[a b c], 'b' => %w[d e f] }
      seen = []
      described_class.each('$.*', input) do |value|
        seen << value
      end
      expect(seen).to eq([%w[a b c], %w[d e f]])
    end

    it 'can modify the queried value' do
      input = { 'a' => %w[a b c], 'b' => %w[d e f] }
      described_class.each('$.*', input) do |arr|
        arr.delete_at(1)
      end
      expected = { 'a' => %w[a c], 'b' => %w[d f] }
      expect(input).to eq(expected)
    end

    it 'returns an enumerator if no block given' do
      expect(described_class.each('$', {})).to be_a(Enumerator)
    end

    it 'returns an enumerator that finds matched values' do
      input = { 'a' => %w[a b c], 'b' => %w[d e f] }
      expected = [%w[a b c], %w[d e f]]
      enum = described_class.each('$.*', input)
      expect(enum.to_a).to eq(expected)
    end

    it 'raises error when no query given' do
      expect {
        described_class.each(nil, {}) { puts }
      }.to raise_error(ArgumentError, /Invalid jsonpath query/)
    end

    it 'raises error when input is not a supported type' do
      expect {
        described_class.each('$', nil) { puts }
      }.to raise_error(ArgumentError, /Invalid input, expecting array or hash/)
    end
  end
end
