# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe ChildSegmentDeleter do
      context 'with name selectors' do
        it 'deletes matching hash elements' do
          input = { 'a' => 1, 'b' => 2, 'c' => 3 }
          Janeway.delete("$['a', 'c']", input)
          expect(input).to eq({ 'b' => 2 })
        end

        it 'deletes nothing from an array' do
          input = %w[a b c]
          Janeway.delete("$['a', 'c']", input)
          expect(input).to eq(%w[a b c])
        end

        it 'returns deleted values' do
          input = { 'a' => 1, 'b' => 2, 'c' => 3 }
          result = Janeway.delete("$['a', 'c']", input)
          expect(result).to eq([1, 3])
        end
      end

      context 'with wildcard selectors' do
        it 'deletes hash elements' do
          input = [{ 'a' => 1, 'b' => 2}, { 'c' => 3} ]
          Janeway.delete("$.*[*, 'c']", input)
          expect(input).to eq([{}, {}])
        end

        it 'deletes array elements' do
          input = [{ 'a' => 1, 'b' => 2}, { 'c' => 3} ]
          Janeway.delete("$[*, 'c']", input)
          expect(input).to eq([])
        end

        it 'returns deleted hash values' do
          input = [{ 'a' => 1, 'b' => 2}, { 'c' => 3} ]
          result = Janeway.delete("$.*[*, 'c']", input)
          expect(result).to eq([1, 2, 3])
        end

        it 'returns deleted array values' do
          input = { 'x' => %w[a b c], 'y' => %w[d e f] }
          result = Janeway.delete("$.*[*, 'c']", input)
          expect(result).to eq(%w[a b c d e f])
        end
      end
    end
  end
end
