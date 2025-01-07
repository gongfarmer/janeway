# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    let(:interpreter) { described_class.new({}) }

    it 'returns input when query is just a root selector' do
      input = { 'a' => 1 }
      expect(described_class.interpret(input, '$')).to eq([input])
    end

    # Compliance test suite requires this to cause an error
    # JsonPath comparison site suggests not to do that
    it 'raises error for empty selector list' do
      input = { 'a' => 1 }
      expect {
        described_class.interpret(input, '$[]')
      }.to raise_error(JsonPath2::Parser::Error, 'Empty selector list')
    end

    it 'interprets dot notation with wildcard selector' do
      input = [[1], [2, 3]]
      expect(described_class.interpret(input, '$.*[1]')).to eq([3])
    end

    ## from compliance test suite
    it 'interprets wildcard shorthand then name shorthand' do
      input = {
        'x' => { 'a' => 'Ax', 'b' => 'Bx' },
        'y' => { 'a' => 'Ay', 'b' => 'By' },
      }
      expect(described_class.interpret(input, '$.*.a')).to eq(['Ax', 'Ay'])
    end

    it 'interprets null' do
      expect(described_class.interpret({}, '$[?@.a==null]')).to eq([])
    end

    it 'interprets filter expression with unary operator' do
      input = [{'a' => 'a', 'd' => 'e'}, {'a' =>'b', 'd' => 'f'}, {'a' =>'d', 'd' => 'f'}]
      query = "$[?!(@.a=='b')]"
      expected = [
        {'a' => 'a', 'd' => 'e'},
        {'a' => 'd', 'd' => 'f'}
      ]
      expect(described_class.interpret(input, query)).to eq(expected)
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
