# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe RootNodeDeleteIf do
      it 'deletes array elements for which the block returns true' do
        input = [1, 2, 3, 4]
        Janeway.enum_for('$', input).delete_if(&:even?)
        expect(input).to eq([1, 3])
      end

      it 'does not delete array elements when the block returns false' do
        input = [1, 2, 3, 4]
        Janeway.enum_for('$', input).delete_if { false }
        expect(input).to eq([1, 2, 3, 4])
      end

      it 'deletes hash elements for which the block returns true' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.enum_for('$', input).delete_if { |value| value == 2 }
        expect(input).to eq({ 'a' => 1, 'c' => 3 })
      end

      it 'does not delete hash elements when the block returns false' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.enum_for('$', input).delete_if { false }
        expect(input).to eq({ 'a' => 1, 'b' => 2, 'c' => 3 })
      end

      it 'returns the values that were deleted from an array' do
        input = [1, 2, 3, 4]
        result = Janeway.enum_for('$', input).delete_if(&:even?)
        expect(result).to eq([2, 4])
      end

      it 'returns the values that were deleted from a hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        result = Janeway.enum_for('$', input).delete_if { |v| v.odd? }
        expect(result).to eq([1, 3])
      end
    end
  end
end
