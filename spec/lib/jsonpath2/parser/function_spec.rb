# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_function' do
      it 'parses the length function' do
        ast = described_class.parse('$[?length(@.authors) >= 5]')
        expect(ast.to_s).to eq('$[?(length(@.authors) >= 5)]')
      end

      xit 'parses the count function' do
        ast = described_class.parse('$[?count(@.*.author) >= 5]', LOG)
        expect(ast).to eq('$[?count(@.*.author) >= 5]')
      end
    end
  end
end
