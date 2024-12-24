# frozen_string_literal: true

require 'jsonpath2'
require 'json'

# https://www.rfc-editor.org/rfc/rfc9535.html#name-name-selector
# https://www.rfc-editor.org/rfc/rfc9535.html#name-examples-2

module JsonPath2
  describe Interpreter do
    describe '#interpret_name_selector' do
      let(:input) do
        JSON.parse(<<~JSON_STRING)
          {
            "o": {"j j": {"k.k": 3}},
            "'": {"@": 2}
          }
        JSON_STRING
      end

      it 'finds matching element when name contains single quoted space' do
        expect(Interpreter.interpret(input, "$.o['j j']")).to eq({ 'k.k' => 3 })
      end
      it 'finds matching element when name contains single quoted space, with nesting' do
        expect(Interpreter.interpret(input, "$.o['j j']['k.k']")).to eq(3)
      end
      it 'finds matching element when name contains double quoted space, with nesting' do
        expect(Interpreter.interpret(input, '$.o["j j"]["k.k"]')).to eq(3)
      end
      it 'finds matching element when name contains single quote' do
        expect(Interpreter.interpret(input, %q($["'"]))).to eq({ '@' => 2 })
      end
      it 'finds matching element when name contains quoted @' do
        expect(Interpreter.interpret(input, %q($["'"]["@"]))).to eq(2)
      end
    end
  end
end
