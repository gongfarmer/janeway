# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe ArraySliceSelectorDeleteIf do
      let(:input) { ('a'..'g').to_a }

      it 'deletes nothing from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.enum_for('$[::]', input).delete_if { true }
        expect(input).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
      end

      it 'deletes all values from an array when given no indices' do
        Janeway.enum_for('$[::]', input).delete_if { true }
        expect(input).to be_empty
      end

      it 'returns deleted values' do
        result = Janeway.enum_for('$[::]', input).delete_if { true }
        expect(result).to eq(('a'..'g').to_a)
      end

      it 'returns deleted values in reverse order when given negative step' do
        result = Janeway.enum_for('$[::-1]', input).delete_if { true }
        expect(input).to be_empty
        expect(result).to eq(('a'..'g').to_a.reverse)
      end

      it 'deletes the correct indexes when step > 1' do
        result = Janeway.enum_for('$[1:5:2]', input).delete_if { true }
        expect(result).to eq(%w[b d])
      end

      it 'returns no values when indexes are out of range' do
        expect(Janeway.enum_for('$[20:25]', input).delete_if { true }).to be_empty
      end

      it 'returns no values when negative indexes is out of range' do
        expect(Janeway.enum_for('$[-20:-25:-1]', input).delete_if { true }).to be_empty
      end

      it 'does not delete values that match the query but receive a non-truthy value from the block' do
        Janeway.enum_for('$[::]', input).delete_if { false }
        expect(input).to eq(('a'..'g').to_a)
      end

      it 'can call instance methods on the matched values within the block' do
        input = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        Janeway.enum_for('$[::]', input).delete_if(&:even?)
        expect(input).to eq([1, 3, 5, 7, 9])
      end

      it 'yields matched value, parent, index and path' do
        Janeway.enum_for('$[::]', input).delete_if do |value, parent, index, path|
          expect(input).to include(value)
          expect(parent).to eq(input)
          expect(index).to be_a(Integer)
          expect(path).to eq("$[#{index}]")
        end
      end
    end
  end
end
