# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe NameSelectorDeleter do
      it 'deletes hash element matching name selector' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.enum_for('$.a', input).delete
        expect(input).to eq({ 'b' => 2, 'c' => 3 })
      end

      it 'deletes nothing from an array' do
        input = %w[a b c]
        Janeway.enum_for('$.a', input).delete
        expect(input).to eq(%w[a b c])
      end

      it 'returns deleted value' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        result = Janeway.enum_for('$.a', input).delete
        expect(result).to eq([1])
      end
    end
  end
end
