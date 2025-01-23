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

    it 'returns an enumerator that returns matched values' do
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

    context 'when iterating with a name selector' do
      it "yields the value and also the hash that contains the value's key" do
        input = { 'a' => { 'b' => { 'c' => 1 } } }
        described_class.each('$.a.b.c', input) do |value, parent|
          expect(value).to eq(1)
          expect(parent).to eq({ 'c' => 1 })
        end
      end
    end

    context 'when iterating with a wildcard selector' do
      it "yields the value and also the array that contains the value" do
        input = %w[a b c]
        described_class.each('$.*', input) do |value, parent|
          expect(input).to include(value)
          expect(parent).to eq(input)
        end
      end

      it "yields the value and also the hash that contains the value" do
        input = { 'a' => { 'b' => { 'c' => 1 } } }
        described_class.each('$.*', input) do |value, parent|
          expect(value).to eq({ 'b' => { 'c' => 1 } })
          expect(parent).to eq(input)
        end
      end
    end

    context 'when iterating with an index selector' do
      it "yields the value and also the array that contains the value" do
        input = %w[a b c]
        described_class.each('$[2]', input) do |value, parent|
          expect(value).to eq('c')
          expect(parent).to eq(input)
        end
      end
    end

    context 'when iterating with an array slice selector' do
      it "yields the value and also the array that contains the value" do
        input = %w[a b c d e f g h]
        seen = []
        described_class.each('$[1:7:2]', input) do |value, parent|
          seen << value
          expect(parent).to eq(input)
        end
        expect(seen).to eq(%w[b d f])
      end
    end

    context 'when iterating with a filter selector' do
      it "yields the value and also the array that contains the value" do
        input = [
          { 'name' => 'bucket', 'cost' => 9.99 },
          { 'name' => 'shovel', 'cost' => 18 },
          { 'name' => 'hose', 'cost' => 20.50 },
          { 'name' => 'trowel', 'cost' => 7.44 },
        ]
        described_class.each('$[? @.cost < 15]', input) do |value, parent|
          expect(%w[bucket trowel]).to include(value['name'])
          expect(parent).to eq(input)
        end
      end
    end

    context 'when iterating with a descendant segment' do
      it "yields the value and also the array that contains the value" do
        input = [
          { 'name' => 'bucket', 'cost' => 9.99 },
        ]
        expected = [
          [{ 'name' => 'bucket', 'cost' => 9.99 }, input],
          ['bucket', { 'name' => 'bucket', 'cost' => 9.99 }],
          [9.99, { 'name' => 'bucket', 'cost' => 9.99 }],
        ]
        described_class.each('$..*', input) do |value, parent|
          expect(expected).to include([value, parent])
        end
      end
    end
  end
end
