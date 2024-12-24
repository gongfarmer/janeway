# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    describe '#interpret_index_selector' do
      let(:input) { ('a'..'c').to_a }
      subject { described_class.new(input) }

      it 'finds matching element' do
        expect(Interpreter.interpret(input, '$[0]')).to eq('a')
        expect(Interpreter.interpret(input, '$[1]')).to eq('b')
        expect(Interpreter.interpret(input, '$[2]')).to eq('c')
      end
      it 'has same meaning for 0 and negative 0' do
        expect(Interpreter.interpret(input, '$[-0]')).to eq('a')
      end
      it 'counts from end for negative index' do
        expect(Interpreter.interpret(input, '$[-1]')).to eq('c')
        expect(Interpreter.interpret(input, '$[-2]')).to eq('b')
        expect(Interpreter.interpret(input, '$[-3]')).to eq('a')
      end
      it 'returns nil when index is out of bounds' do
        expect(Interpreter.interpret(input, '$[3]')).to be(nil)
        expect(Interpreter.interpret(input, '$[-4]')).to be(nil)
      end
      it 'allows multiple comma-separated index selectors' do
        expect(Interpreter.interpret(input, '$[0,1,2]')).to eq(input)
        expect(Interpreter.interpret(input, '$[0,1,2,3,4,5]')).to eq(input)
      end
    end
  end
end
