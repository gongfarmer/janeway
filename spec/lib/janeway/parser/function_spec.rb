# frozen_string_literal: true

require 'janeway'

module Janeway
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

      it 'parses a function parameter with incorrect type number' do
        # length() does not expect this type, Parser must not crash though.
        ast = described_class.parse('$[?length(5) >= 5]')
        expect(ast.to_s).to eq('$[?(length(5) >= 5)]')
      end

      it 'parses a function parameter with incorrect type boolean' do
        # length() does not expect this type, Parser must not crash though.
        ast = described_class.parse('$[?length(true) >= 5]')
        expect(ast.to_s).to eq('$[?(length(true) >= 5)]')
      end

      it 'parses a function parameter with incorrect type null' do
        # length() does not expect this type, Parser must not crash though.
        ast = described_class.parse('$[?length(null) >= 5]')
        expect(ast.to_s).to eq('$[?(length(null) >= 5)]')
      end

      it 'raises error when there is space between function name and parentheses' do
        expect {
          described_class.parse('$[?length (@.authors) >= 5]')
        }.to raise_error(Error, 'Function name "length" must not be followed by whitespace')
      end
    end
  end
end
