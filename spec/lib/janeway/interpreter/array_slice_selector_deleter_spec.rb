# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe ArraySliceSelectorDeleter do
      let(:input) { ('a'..'g').to_a }

      it 'deletes nothing from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.on('$[::]', input).delete
        expect(input).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
      end

      it 'deletes all values from an array when given no indices' do
        Janeway.on('$[::]', input).delete
        expect(input).to be_empty
      end

      it 'returns deleted values' do
        result = Janeway.on('$[::]', input).delete
        expect(result).to eq(('a'..'g').to_a)
      end

      it 'returns deleted values in reverse order when given negative step' do
        result = Janeway.on('$[::-1]', input).delete
        expect(input).to be_empty
        expect(result).to eq(('a'..'g').to_a.reverse)
      end

      it 'deletes the correct indexes when step > 1' do
        result = Janeway.on('$[1:5:2]', input).delete
        expect(result).to eq(%w[b d])
      end

      it 'returns no values when indexes are out of range' do
        expect(Janeway.on('$[20:25]', input).delete).to be_empty
      end

      it 'returns no values when negative indexes is out of range' do
        expect(Janeway.on('$[-20:-25:-1]', input).delete).to be_empty
      end
    end
  end
end
