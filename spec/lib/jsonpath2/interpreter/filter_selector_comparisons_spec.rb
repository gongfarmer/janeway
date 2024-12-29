# frozen_string_literal: true

require 'json'
require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    describe '#interpret_filter_selector' do
      let(:input) do
        JSON.parse(<<~JSON_STRING)
          {
            "obj": {"x": "y"},
            "arr": [2, 3]
          }
        JSON_STRING
      end

      it 'compares empty node lists with ==' do
        result = described_class.interpret(input, '$[? $.absent1 == $.absent2 ]')
        expect(result).to be(true)
      end

      it 'compares empty node lists with <=' do
        result = described_class.interpret(input, '$[? $.absent1 <= $.absent2 ]')
        expect(result).to be(true)
      end

      it 'compares empty node list with string literal using ==' do
        result = described_class.interpret(input, "$[? $.absent == 'g' ]")
        expect(result).to be(false)
      end

      it 'compares empty node lists with !=' do
        result = described_class.interpret(input, '$[? $.absent1 != $.absent2 ]')
        expect(result).to be(false)
      end

      it 'compares empty node list with string literal using !=' do
        result = described_class.interpret(input, "$[? $.absent != 'g' ]")
        expect(result).to be(true)
      end

      it 'performs numeric comaprison with <=' do
        result = described_class.interpret(input, "$[? 1 <= 2]")
        expect(result).to be(true)
      end

      it 'performs numeric comaprison with >' do
        result = described_class.interpret(input, "$[? 1 > 2]")
        expect(result).to be(false)
      end

      it 'compares number to string (type mismatch)' do
        result = described_class.interpret(input, "$[? 13 == '13']")
        expect(result).to be(false)
      end

      it 'compares string to string with <=' do
        result = described_class.interpret(input, "$[? 'a' <= 'b']")
        expect(result).to be(true)
      end

      it 'compares hash to array with == (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj == $.arr]')
        expect(result).to be(false)
      end

      it 'compares hash to array with != (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj != $.arr]')
        expect(result).to be(true)
      end

      it 'compares hash to self with ==' do
        result = described_class.interpret(input, '$[? $.obj == $.obj]')
        expect(result).to be(true)
      end

      it 'compares hash to self with !=' do
        result = described_class.interpret(input, '$[? $.obj != $.obj]')
        expect(result).to be(false)
      end

      it 'compares array to self with ==' do
        result = described_class.interpret(input, '$[? $.arr == $.arr]')
        expect(result).to be(true)
      end

      it 'compares array to self with !=' do
        result = described_class.interpret(input, '$[? $.arr != $.arr]')
        expect(result).to be(false)
      end

      it 'compares hash to number with ==' do
        result = described_class.interpret(input, '$[? $.obj == 17]')
        expect(result).to be(false)
      end

      it 'compares hash to number with !=' do
        result = described_class.interpret(input, '$[? $.obj != 17]')
        expect(result).to be(true)
      end

      it 'compares hash to array with <= (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj <= $.arr]')
        expect(result).to be(false)
      end

      it 'compares hash to array with < (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj < $.arr]')
        expect(result).to be(false)
      end

      it 'compares hash to self with <=' do
        result = described_class.interpret(input, '$[? $.obj <= $.obj]')
        expect(result).to be(true)
      end

      it 'compares array to self with <=' do
        result = described_class.interpret(input, '$[? $.arr <= $.arr]')
        expect(result).to be(true)
      end

      it 'compares number to array with <=' do
        result = described_class.interpret(input, '$[? 1 <= $.arr]')
        expect(result).to be(false)
      end

      it 'compares number to array with >=' do
        result = described_class.interpret(input, '$[? 1 >= $.arr]')
        expect(result).to be(false)
      end

      it 'compares number to array with >' do
        result = described_class.interpret(input, '$[? 1 > $.arr]')
        expect(result).to be(false)
      end

      it 'compares number to array with <' do
        result = described_class.interpret(input, '$[? 1 < $.arr]')
        expect(result).to be(false)
      end

      it 'compares true with self using <=' do
        result = described_class.interpret(input, '$[? true <= true]')
        expect(result).to be(true)
      end

      it 'compares true with self using >' do
        result = described_class.interpret(input, '$[? true > true]')
        expect(result).to be(false)
      end
    end
  end
end
