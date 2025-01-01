# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    describe '#interpret_index_selector' do
      let(:input) { ('a'..'c').to_a }

      it 'finds matching element' do
        expect(described_class.interpret(input, '$[0]')).to eq(['a'])
        expect(described_class.interpret(input, '$[1]')).to eq(['b'])
        expect(described_class.interpret(input, '$[2]')).to eq(['c'])
      end

      it 'has same meaning for 0 and negative 0' do
        expect(described_class.interpret(input, '$[-0]')).to eq(['a'])
      end

      it 'counts from end for negative index' do
        expect(described_class.interpret(input, '$[-1]')).to eq(['c'])
        expect(described_class.interpret(input, '$[-2]')).to eq(['b'])
        expect(described_class.interpret(input, '$[-3]')).to eq(['a'])
      end

      it 'returns nil when index is out of bounds' do
        expect(described_class.interpret(input, '$[3]')).to be_empty
        expect(described_class.interpret(input, '$[-4]')).to be_empty
      end

      it 'allows multiple comma-separated index selectors' do
        expect(described_class.interpret(input, '$[0,1,2]')).to eq(input)
        expect(described_class.interpret(input, '$[0,1,2,3,4,5]')).to eq(input)
      end
    end
  end
end
