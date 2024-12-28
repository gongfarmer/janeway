# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_array_slice_selector' do
      it 'parses all 3 components' do
        ast = described_class.parse('$[6:12:2]')
        expect(ast).to eq('$[6:12:2]')
      end

      it 'defaults to step 1' do
        ast = described_class.parse('$[6:12]')
        expect(ast).to eq('$[6:12:1]')
      end

      it 'ends at the last index if step is positive' do
        ast = described_class.parse('$[6::1]')
        expect(ast).to eq('$[6:-1:1]')
      end

      it 'ends at the start index if step is negative' do
        ast = described_class.parse('$[6::-1]')
        expect(ast).to eq('$[6:0:-1]')
      end

      it 'iterates from end to start if only negative step is given' do
        ast = described_class.parse('$[::-1]')
        expect(ast).to eq('$[-1:0:-1]')
      end
    end
  end
end
