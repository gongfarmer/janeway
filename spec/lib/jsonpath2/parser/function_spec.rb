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
        # Regexp looks much different after conversion from iregexp format to ruby regexp equivalnt
        expect(ast.to_s).to eq('$[?match(@.date,(?-mix:\A(?:1974-05-[^\n\r][^\n\r])\z))]')
      end
    end
  end
end
