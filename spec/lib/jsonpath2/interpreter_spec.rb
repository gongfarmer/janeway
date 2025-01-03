# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    let(:interpreter) { described_class.new({}) }

    it 'returns input when query is just a root selector' do
      input = { 'a' => 1 }
      expect(described_class.interpret(input, '$')).to eq([input])
    end

    it 'returns nothing for empty brackets' do
      input = { 'a' => 1 }
      expect(described_class.interpret(input, '$[]')).to eq([])
    end

    it 'interprets dot notation with wildcard selector' do
      input = [[1], [2, 3]]
      expect(described_class.interpret(input, '$.*[1]')).to eq([3])
    end

    describe '#truthy' do
      it 'says nil is false' do
        expect(interpreter.send(:truthy?, nil)).to be(false)
      end

      it 'says false is false' do
        expect(interpreter.send(:truthy?, false)).to be(false)
      end

      it 'says empty array is false' do
        expect(interpreter.send(:truthy?, [])).to be(false)
      end

      it 'says array of nil is false' do
        expect(interpreter.send(:truthy?, [nil, nil])).to be(false)
      end

      it 'says array of false is false' do
        expect(interpreter.send(:truthy?, [false, false])).to be(false)
      end
    end
  end
end
