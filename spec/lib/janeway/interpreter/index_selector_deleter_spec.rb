# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe IndexSelectorDeleter do
      let(:input) { %w[a b c] }

      it 'deletes nothing from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.enum_for('$[1]', input).delete
        expect(input).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
      end

      it 'deletes value from an array' do
        Janeway.enum_for('$[2]', input).delete
        expect(input).to eq(%w[a b])
      end

      it 'returns deleted value' do
        result = Janeway.enum_for('$[2]', input).delete
        expect(result).to eq(['c'])
      end

      it 'returns deleted value from negative index' do
        expect(Janeway.enum_for('$[-3]', input).delete).to eq(['a'])
      end

      it 'returns no values when positive index is out of range' do
        expect(Janeway.enum_for('$[3]', input).delete).to be_empty
      end

      it 'returns no values when negative index is out of range' do
        expect(Janeway.enum_for('$[-4]', input).delete).to be_empty
      end
    end
  end
end
