# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Interpreter do
    # rubocop: disable RSpec/MultipleExpectations
    describe '#interpret_index_selector' do
      let(:input) { ('a'..'c').to_a }

      it 'finds matching element' do
        expect(described_class.interpret(input, '$[0]')).to eq(['a'])
        expect(described_class.interpret(input, '$[1]')).to eq(['b'])
        expect(described_class.interpret(input, '$[2]')).to eq(['c'])
      end

      # CTS "index selector, -0",
      it 'raises error for negative zero' do
        expect {
          described_class.interpret(input, '$[-0]')
        }.to raise_error(Error, /Negative zero is not allowed in an index selector/)
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

      it 'does not crash when applying index selector to string' do
        expect(described_class.interpret('hello world', '$[0]')).to be_empty
      end

      # CTS "index selector, min exact index"
      it 'handles the minimum possible index value', skip: on_truffleruby do
        expect(described_class.interpret(%w[one two], '$[-9007199254740991]')).to be_empty
      end

      # CTS "index selector, min exact index - 1"
      it 'raises error given an index that is smaller than minimum', skip: on_truffleruby  do
        expect {
          described_class.interpret([], '$[-9007199254740992]')
        }.to raise_error(Error, /Index selector value too small/)
      end

      # CTS "index selector, max exact index"
      it 'handles the maximum possible index value', skip: on_truffleruby  do
        expect(described_class.interpret(%w[one two], '$[9007199254740991]')).to be_empty
      end

      # CTS "index selector, max exact index + 1"
      it 'raises error given an index that is larger than maximum' do
        expect {
          described_class.interpret([], '$[9007199254740992]')
        }.to raise_error(Error, /Index selector value too large/)
      end
    end
    # rubocop: enable RSpec/MultipleExpectations
  end
end
