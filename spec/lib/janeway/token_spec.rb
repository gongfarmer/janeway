# frozen_string_literal: true

require 'janeway/token'
require 'janeway/location'

module Janeway
  describe Token do
    let(:location) { Location.new(0, 1) }

    describe '#==' do
      it 'returns true when comparing two tokens with the same type, lexeme, and literal' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '1', 1, location)
        expect(t1 == t2).to be(true)
      end

      it 'returns false when comparing two tokens with different type' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:string, '1', 1, location)
        expect(t1 == t2).to be(false)
      end

      it 'returns false when comparing two tokens with different lexeme' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '2', 1, location)
        expect(t1 == t2).to be(false)
      end

      it 'returns false when comparing two tokens with different literal' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '1', 2, location)
        expect(t1 == t2).to be(false)
      end

      it 'does not mutate self when comparing two tokens with different literal' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '1', 2, location)
        t1 == t2
        expect(t1.literal).to eq(1)
      end

      it 'compares literal when other is an Integer' do
        t = described_class.new(:number, '1', 1, location)
        expect(t == 1).to be(true)
        expect(t == 2).to be(false)
      end

      it 'compares literal when other is a String' do
        t = described_class.new(:string, '"foo"', 'foo', location)
        expect(t == 'foo').to be(true)
        expect(t == 'bar').to be(false)
      end

      it 'compares type when other is a Symbol' do
        t = described_class.new(:number, '1', 1, location)
        expect(t == :number).to be(true)
        expect(t == :string).to be(false)
      end
    end
  end
end
