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
        expect(described_class.interpret(input, "$.o['j j']")).to eq([{ 'k.k' => 3 }])
      end

      it 'finds matching element when name contains single quoted space, with nesting' do
        expect(described_class.interpret(input, "$.o['j j']['k.k']")).to eq([3])
      end

      it 'finds matching element when name contains double quoted space, with nesting' do
        expect(described_class.interpret(input, '$.o["j j"]["k.k"]')).to eq([3])
      end

      it 'finds matching element when name contains single quote' do
        expect(described_class.interpret(input, %q($["'"]))).to eq([{ '@' => 2 }])
      end

      it 'finds matching element when name contains @ character' do
        expect(described_class.interpret(input, %q($["'"]["@"]))).to eq([2])
      end

      it 'interprets query with unicode surrogate pair' do
        query = '$["\\uD834\\uDD1E"]'
        expect(described_class.interpret({}, query)).to eq([])
      end
    end
  end
end
