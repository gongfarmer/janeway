# frozen_string_literal: true

require 'json'
require 'janeway'

module Janeway
  module Interpreters
    describe FilterSelectorDeleter do
      context 'when input is a hash' do
        let(:input) do
          { 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 }, 'c' => { 'x' => 3, 'y' => nil } }
        end

        it 'deletes and returns elements that match a comparison test' do
          result = Janeway.delete('$[? @.x<3]', input)
          expect(result).to eq([{ 'x' => 1 }, { 'x' => 2 }])
          expect(input).to eq({ 'c' => { 'x' => 3, 'y' => nil } })
        end

        it 'deletes and returns nothing when filter does not match' do
          result = Janeway.delete('$[? @.y==3]', input)
          expect(result).to be_empty
          expect(input.size).to eq(3)
        end

        it 'deletes and returns elements that match an existence test' do
          result = Janeway.delete('$[? @.y]', input)
          expect(result).to eq([{ 'x' => 3, 'y' => nil }])
          expect(input).to eq({ 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 }})
        end
      end

      context 'when input is an array' do
        let(:input) do
          [
            { 'x' => 1 },
            { 'x' => 2 },
            { 'x' => 3, 'y' => nil },
          ]
        end

        it 'deletes and returns elements that match the filter' do
          result = Janeway.delete('$[? @.x<3]', input)
          expect(result).to eq([{ 'x' => 1 }, { 'x' => 2 }])
          expect(input).to eq([{ 'x' => 3, 'y' => nil }])
        end

        it 'deletes and returns elements that match an existence test' do
          result = Janeway.delete('$[? @.y]', input)
          expect(result).to eq([{ 'x' => 3, 'y' => nil }])
          expect(input).to eq([{ 'x' => 1 }, { 'x' => 2 }])
        end
      end
    end
  end
end
