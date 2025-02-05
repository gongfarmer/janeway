# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe ChildSegmentDeleteIf do
      context 'with name selectors' do
        it 'deletes matching hash elements that return a truthy value from the block' do
          input = { 'a' => 1, 'b' => 2, 'c' => 3 }
          Janeway.enum_for("$['a', 'b', 'c']", input).delete_if(&:odd?)
          expect(input).to eq({ 'b' => 2 })
        end

        it 'deletes nothing from an array' do
          input = %w[a b c]
          Janeway.enum_for("$['a', 'c']", input).delete_if { |v| v == 'a' }
          expect(input).to eq(%w[a b c])
        end

        it 'returns deleted values' do
          input = { 'a' => 1, 'b' => 2, 'c' => 3 }
          result = Janeway.enum_for("$['a', 'c']", input).delete_if { |v| v == 1 }
          expect(result).to eq([1])
        end
      end

      context 'with wildcard selectors' do
        it 'deletes hash elements for which a truthy value is returned from the block' do
          input = [{ 'a' => 1, 'b' => 2 }, { 'c' => 1 }]
          Janeway.enum_for("$.*[*, 'c']", input).delete_if { |value| value == 1 }
          expect(input).to eq([{ 'b' => 2 }, {}])
        end

        it 'returns deleted hash values' do
          input = [{ 'a' => 1, 'b' => 2 }, [3]]
          result = Janeway.enum_for("$[*, 'c']", input).delete_if { |value| value.is_a?(Hash) }
          expect(result).to eq([{ 'a' => 1, 'b' => 2 }])
        end

        it 'deletes array elements' do
          input = [{ 'a' => 1, 'b' => 2 }, [3]]
          Janeway.enum_for("$[*, 'c']", input).delete_if { |value| value.is_a?(Hash) }
          expect(input).to eq([[3]])
        end

        it 'returns deleted array values' do
          input = { 'x' => %w[a b c], 'y' => %w[d e f] }
          result = Janeway.enum_for("$.*[*, 'c']", input).delete_if { |char| char.ord.odd? }
          expect(result).to eq(%w[a c e])
        end
      end
    end
  end
end
