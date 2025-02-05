# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe IndexSelectorDeleteIf do
      let(:input) { %w[a b c d e f] }

      it 'deletes nothing from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.enum_for('$[1]', input).delete_if { true }
        expect(input).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
      end

      it 'deletes single value from an array if block returns true' do
        Janeway.enum_for('$[2]', input).delete_if { |value| value == 'c' }
        expect(input).to eq(%w[a b d e f])
      end

      it 'returns deleted value' do
        result = Janeway.enum_for('$[2]', input).delete_if { true }
        expect(result).to eq(['c'])
      end

      it 'does not delete value array if block returns false' do
        Janeway.enum_for('$[2]', input).delete_if { |value| value == 'a' }
        expect(input).to eq(%w[a b c d e f])
      end

      it 'returns deleted value from negative index' do
        expect(Janeway.enum_for('$[-6]', input).delete_if { true }).to eq(['a'])
      end

      it 'returns no values when positive index is out of range' do
        expect(Janeway.enum_for('$[6]', input).delete_if { true }).to be_empty
      end

      it 'returns no values when negative index is out of range' do
        expect(Janeway.enum_for('$[-7]', input).delete_if { true }).to be_empty
      end
    end
  end
end
