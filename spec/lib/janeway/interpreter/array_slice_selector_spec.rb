# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Interpreter do
    describe '#interpret_array_slice_selector' do
      let(:input) { ('a'..'g').to_a }

      it 'counts by 1 when slice uses default step' do
        expect(described_class.interpret(input, '$[1:3]')).to eq(%w[b c])
      end

      it 'counts to the end when slice has no end index' do
        expect(described_class.interpret(input, '$[5:]')).to eq(%w[f g])
      end

      it 'counts by 2 when slice has step 2' do
        expect(described_class.interpret(input, '$[1:5:2]')).to eq(%w[b d])
      end

#      it 'counts backwards by 2 when slice has negative step' do
#        #[a b c d e f g]
#        # 5,2,-2
#        expect(described_class.interpret(input, '$[5:1:-2]')).to eq(%w[f d])
#      end

      it 'selects nothing when step is 0' do
        expect(described_class.interpret(input, '$[::0]')).to be_empty
      end

      it 'selects everything when no start, end or step are given' do
        expect(described_class.interpret(input, '$[:]')).to eq(input)
      end

      context 'when slice has no start or end and uses negative step' do
        it 'finds all elements in reverse order' do
          expect(described_class.interpret(input, '$[::-1]')).to eq(input.reverse)
        end
      end

      context 'when array slice selectors are in serial' do
        let(:input) { [%w[a b c], %w[d e f], %w[g h i]] }

        it 'finds all elements' do
          expected = [%w[d e f], %w[g h i]]
          expect(described_class.interpret(input, '$[1:3][:]')).to eq(expected)
        end
      end

      # CTS "slice selector, negative step with default start"
      it 'omits the first element when doing negative step and given explicit 0 end index' do
        input = [0, 1, 2, 3]
        expected = [3, 2, 1]
        expect(described_class.interpret(input, '$[:0:-1]')).to eq(expected)
      end
    end
  end
end
