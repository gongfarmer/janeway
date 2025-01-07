# frozen_string_literal: true

require 'json'
require 'jsonpath2'

# Examples from https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.5.3-4
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
        expect(result).not_to be_empty
      end

      it 'compares empty node lists with <=' do
        result = described_class.interpret(input, '$[? $.absent1 <= $.absent2 ]')
        expect(result).not_to be_empty
      end

      it 'compares empty node list with string literal using ==' do
        result = described_class.interpret(input, "$[? $.absent == 'g' ]")
        expect(result).to be_empty
      end

      it 'compares empty node lists with !=' do
        result = described_class.interpret(input, '$[? $.absent1 != $.absent2 ]')
        expect(result).to be_empty
      end

      it 'compares empty node list with string literal using !=' do
        result = described_class.interpret(input, "$[? $.absent != 'g' ]")
        expect(result).not_to be_empty
      end

      it 'performs numeric comaprison with <=' do
        result = described_class.interpret(input, '$[? 1 <= 2]')
        expect(result).not_to be_empty
      end

      it 'performs numeric comaprison with >' do
        result = described_class.interpret(input, '$[? 1 > 2]')
        expect(result).to be_empty
      end

      it 'compares number to string (type mismatch)' do
        result = described_class.interpret(input, "$[? 13 == '13']")
        expect(result).to be_empty
      end

      it 'compares string to string with <=' do
        result = described_class.interpret(input, "$[? 'a' <= 'b']")
        expect(result).not_to be_empty
      end

      it 'compares hash to array with == (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj == $.arr]')
        expect(result).to be_empty
      end

      it 'compares hash to array with != (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj != $.arr]')
        expect(result).not_to be_empty
      end

      it 'compares hash to self with ==' do
        result = described_class.interpret(input, '$[? $.obj == $.obj]')
        expect(result).not_to be_empty
      end

      it 'compares hash to self with !=' do
        result = described_class.interpret(input, '$[? $.obj != $.obj]')
        expect(result).to be_empty
      end

      it 'compares array to self with ==' do
        result = described_class.interpret(input, '$[? $.arr == $.arr]')
        expect(result).not_to be_empty
      end

      it 'compares array to self with !=' do
        result = described_class.interpret(input, '$[? $.arr != $.arr]')
        expect(result).to be_empty
      end

      it 'compares hash to number with ==' do
        result = described_class.interpret(input, '$[? $.obj == 17]')
        expect(result).to be_empty
      end

      it 'compares hash to number with !=' do
        result = described_class.interpret(input, '$[? $.obj != 17]')
        expect(result).not_to be_empty
      end

      it 'compares hash to array with <= (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj <= $.arr]')
        expect(result).to be_empty
      end

      it 'compares hash to array with < (type mismatch)' do
        result = described_class.interpret(input, '$[? $.obj < $.arr]')
        expect(result).to be_empty
      end

      it 'compares hash to self with <=' do
        result = described_class.interpret(input, '$[? $.obj <= $.obj]')
        expect(result).not_to be_empty
      end

      it 'compares array to self with <=' do
        result = described_class.interpret(input, '$[? $.arr <= $.arr]')
        expect(result).not_to be_empty
      end

      it 'compares number to array with <=' do
        result = described_class.interpret(input, '$[? 1 <= $.arr]')
        expect(result).to be_empty
      end

      it 'compares number to array with >=' do
        result = described_class.interpret(input, '$[? 1 >= $.arr]')
        expect(result).to be_empty
      end

      it 'compares number to array with >' do
        result = described_class.interpret(input, '$[? 1 > $.arr]')
        expect(result).to be_empty
      end

      it 'compares number to array with <' do
        result = described_class.interpret(input, '$[? 1 < $.arr]')
        expect(result).to be_empty
      end

      it 'compares true with self using <=' do
        result = described_class.interpret(input, '$[? true <= true]')
        expect(result).not_to be_empty
      end

      it 'compares true with self using >' do
        result = described_class.interpret(input, '$[? true > true]')
        expect(result).to be_empty
      end

      it 'compares number to exponential positive number' do
        result = described_class.interpret(input, '$[? 1 < 5e+2]')
        expect(result).not_to be_empty
      end

      it 'compares number to exponential negative number' do
        result = described_class.interpret(input, '$[? 1 < 5e-2]')
        expect(result).to be_empty
      end

      # CTS: "filter, equals number, negative zero and zero"
      it 'handles equality test with negative zero' do
        query = '$[?@.a==-0]'
        ast = Parser.parse(query)
        pp ast.expressions

        input = [{ 'a' => 0, 'd' => 'e' }, { 'a' => 0.1, 'd' => 'f' }, { 'a' => '0', 'd' => 'g' }]
        expected = [{ 'a' => 0, 'd' => 'e' }]
        result = described_class.interpret(input, query)
        expect(result).to eq(expected)
      end
    end
  end
end
