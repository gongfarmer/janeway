# frozen_string_literal: true

require 'json'
require 'janeway'

module Janeway
  module Interpreters
    describe FilterSelectorDeleteIf do
      context 'when input is a hash' do
        let(:input) do
          { 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 }, 'c' => { 'x' => 3, 'y' => nil } }
        end

        it 'deletes and returns elements that match a comparison test and return true from block' do
          result = Janeway.enum_for('$[? @.x<3]', input).delete_if { |value| value['x'] == 2 }
          expect(result).to eq([{ 'x' => 2 }])
          expect(input).to eq({ 'a' => { 'x' => 1 }, 'c' => { 'x' => 3, 'y' => nil } })
        end

        it 'deletes and returns nothing when filter does not match' do
          result = Janeway.enum_for('$[? @.y==3]', input).delete_if { true }
          expect(result).to be_empty
          expect(input.size).to eq(3)
        end

        it 'deletes and returns elements that match an existence test and return true from block' do
          result = Janeway.enum_for('$[? @.y]', input).delete_if { |value| value['x'] == 3 }
          expect(result).to eq([{ 'x' => 3, 'y' => nil }])
          expect(input).to eq({ 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 } })
        end

        it 'does not delete elements that match an existence test but return false from block' do
          result = Janeway.enum_for('$[? @.y]', input).delete_if { |value| value['x'] == 1 }
          expect(result).to be_empty
          expect(input).to eq({ 'a' => { 'x' => 1 }, 'b' => { 'x' => 2 }, 'c' => { 'x' => 3, 'y' => nil } })
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

        it 'deletes and returns elements that match the filter and return true from block' do
          result = Janeway.enum_for('$[? @.x<3]', input).delete_if { |value| value['x'].odd? }
          expect(result).to eq([{ 'x' => 1 }])
          expect(input).to eq([{ 'x' => 2 }, { 'x' => 3, 'y' => nil }])
        end

        it 'deletes and returns elements that match an existence test and return true from block' do
          result = Janeway.enum_for('$[? @.y]', input).delete_if { |value| value['x'] == 3 }
          expect(result).to eq([{ 'x' => 3, 'y' => nil }])
          expect(input).to eq([{ 'x' => 1 }, { 'x' => 2 }])
        end

        it 'does not delete elements that match an existence test but return false from block' do
          result = Janeway.enum_for('$[? @.y]', input).delete_if { |value| value['x'] == 1 }
          expect(result).to be_empty
          expect(input).to eq([{ 'x' => 1 }, { 'x' => 2 }, { 'x' => 3, 'y' => nil }])
        end
      end
    end
  end
end
