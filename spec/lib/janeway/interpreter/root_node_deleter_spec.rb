# frozen_string_literal: true

require 'janeway'

module Janeway
  module Interpreters
    describe RootNodeDeleter do
      it 'deletes all array elements' do
        input = %w[a b c]
        Janeway.on('$', input).delete
        expect(input).to be_empty
      end

      it 'deletes all hash elements' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        Janeway.on('$', input).delete
        expect(input).to be_empty
      end

      it 'returns values deleted from array' do
        input = %w[a b c]
        result = Janeway.on('$', input).delete
        expect(result).to eq(%w[a b c])
      end

      it 'returns values deleted from hash' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        result = Janeway.on('$', input).delete
        expect(result).to eq([1, 2, 3])
      end
    end
  end
end
