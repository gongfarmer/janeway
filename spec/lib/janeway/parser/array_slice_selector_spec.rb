# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Parser do
    describe '#parse_array_slice_selector' do
      it 'parses all 3 components' do
        ast = described_class.parse('$[6:12:2]')
        expect(ast).to eq('$[6:12:2]')
      end

      it 'defaults to step 1' do
        ast = described_class.parse('$[6:12]')
        expect(ast.to_s).to eq('$[6:12]')
      end

      it 'ends at the last index if step is positive' do
        ast = described_class.parse('$[6::1]')
        expect(ast.to_s).to eq('$[6::1]')
      end

      it 'ends at the start index if step is negative' do
        ast = described_class.parse('$[6::-1]')
        expect(ast.to_s).to eq('$[6::-1]')
      end

      it 'iterates from end to start if only negative step is given' do
        ast = described_class.parse('$[::-1]')
        expect(ast).to eq('$[::-1]')
      end

      # CTS "slice selector, start, -0",
      it 'raises error for negative zero in the start position' do
        expect {
          described_class.parse('$[-0::]')
        }.to raise_error(Error, 'Negative zero is not allowed in an array slice selector')
      end

      # CTS "slice selector, end, -0",
      it 'raises error for negative zero in the end position' do
        expect {
          described_class.parse('$[:-0:]')
        }.to raise_error(Error, 'Negative zero is not allowed in an array slice selector')
      end
    end
  end
end
