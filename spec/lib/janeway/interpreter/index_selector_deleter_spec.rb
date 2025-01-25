# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe IndexSelectorDeleter do
      let(:input) { %w[a b c] }

      it 'deletes nothing from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.delete('$[1]', input)
        expect(input).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
      end

      it 'deletes value from an array' do
        Janeway.delete('$[2]', input)
        expect(input).to eq(%w[a b])
      end

      it 'returns deleted value' do
        result = Janeway.delete('$[2]', input)
        expect(result).to eq(['c'])
      end

      it 'returns deleted value from negative index' do
        expect(Janeway.delete('$[-3]', input)).to eq(['a'])
      end

      it 'returns no values when positive index is out of range' do
        expect(Janeway.delete('$[3]', input)).to be_empty
      end

      it 'returns no values when negative index is out of range' do
        expect(Janeway.delete('$[-4]', input)).to be_empty
      end
    end
  end
end
