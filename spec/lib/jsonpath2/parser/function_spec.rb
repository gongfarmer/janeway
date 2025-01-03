# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_function' do
      it 'parses the length function' do
        ast = described_class.parse('$[?length(@.authors) >= 5]')
        expect(ast.to_s).to eq('$[?(length(@.authors) >= 5)]')
      end

      it 'parses the count function' do
        ast = described_class.parse('$[?count(@.*.author) >= 5]')
        expect(ast.to_s).to eq('$[?(count(@.*.author) >= 5)]')
      end

      it 'parses the match function' do
        ast = described_class.parse('$[?match(@.date, "1974-05-..")]')
        expect(ast.to_s).to eq("$[?match(@.date,'1974-05-..')]")
      end

      it 'parses the value function' do
        ast = described_class.parse("$[?value(@..color) == 'red']")
        expect(ast.to_s).to eq("$[?(value(@..color) == 'red')]")
      end
    end
  end
end
