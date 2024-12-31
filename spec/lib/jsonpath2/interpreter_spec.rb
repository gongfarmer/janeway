# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    let(:interpreter) { described_class.new({}) }

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
