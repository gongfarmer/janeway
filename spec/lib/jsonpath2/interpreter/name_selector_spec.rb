# frozen_string_literal: true

require 'jsonpath2'
require 'json'

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

      it 'finds matching element when name contains quoted space' do
        # From https://ietf-wg-jsonpath.github.io/draft-ietf-jsonpath-base/draft-ietf-jsonpath-base.html#name-examples-2
        expect(Interpreter.interpret(input, "$.o['j j']")).to eq({ 'k.k' => 3 })
      end
      it 'finds matching element when name contains single quote' do
        # From https://ietf-wg-jsonpath.github.io/draft-ietf-jsonpath-base/draft-ietf-jsonpath-base.html#name-examples-2
        expect(Interpreter.interpret(input, %q($["'"]))).to eq({ '@' => 2 })
      end
      it 'finds matching element when name contains quoted @' do
        expect(Interpreter.interpret(input, %q($["'"]["@"]))).to eq(2)
      end
    end
  end
end
