# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe WildcardSelectorDeleteIf do
      it 'deletes all array elements for which the block returns true' do
        input = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        Janeway.enum_for('$.*', input).delete_if(&:odd?)
        expect(input).to eq([0, 2, 4, 6, 8])
      end

      it 'returns values deleted from array' do
        input = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        result = Janeway.enum_for('$.*', input).delete_if(&:odd?)
        expect(result).to eq([1, 3, 5, 7, 9])
      end

      it 'deletes all hash elements for which the block returns true' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4 }
        Janeway.enum_for('$.*', input).delete_if(&:odd?)
        expect(input).to eq({ 'b' => 2, 'd' => 4 })
      end

      it 'returns values deleted from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4 }
        result = Janeway.enum_for('$.*', input).delete_if(&:odd?)
        expect(result).to eq([1, 3])
      end
    end
  end
end
