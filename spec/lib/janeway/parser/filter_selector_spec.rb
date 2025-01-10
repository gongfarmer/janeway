# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Parser do
    describe '#parse_filter_selector' do
      let(:query) { '$[?@.price < 10]' }

      it 'raises error when literal is compared literal in logical comparison' do
        expect {
          described_class.parse('$[? false || true]')
        }.to raise_error(Error, /Literal "true" must be compared to an expression/)
      end

      it 'parses current node operator' do
        ast = described_class.parse('$[? @.key1 == true]')
        expect(ast).to eq('$[?(@.key1 == true)]')
      end

      ### Examples from https://www.rfc-editor.org/rfc/rfc9535.html#name-examples-6

      it 'handles equality operator with nodelists' do
        ast = described_class.parse('$[? $.absent1 == $.absent2]')
        expect(ast).to eq('$[?($.absent1 == $.absent2)]')
      end

      it 'handles less than or equal to operator' do
        ast = described_class.parse('$[? $.absent1 <= $.absent2]')
        expect(ast).to eq('$[?($.absent1 <= $.absent2)]')
      end

      it 'compares name selector with string literal' do
        ast = described_class.parse("$[? $.absent == 'g']")
        expect(ast).to eq("$[?($.absent == 'g')]")
      end

      it 'handles non-equality operator with nodelists' do
        ast = described_class.parse('$[? $.absent1 != $.absent2]')
        expect(ast).to eq('$[?($.absent1 != $.absent2)]')
      end

      it 'handles non-equality operator with node list and string literal' do
        ast = described_class.parse("$[? $.absent != 'g']")
        expect(ast).to eq("$[?($.absent != 'g')]")
      end

      it 'handles numeric comparison with less-than-or-equal' do
        ast = described_class.parse('$[? 1 <= 2]')
        expect(ast).to eq('$[?(1 <= 2)]')
      end

      it 'handles numeric comparison with greater-than' do
        ast = described_class.parse('$[? 1 > 2]')
        expect(ast).to eq('$[?(1 > 2)]')
      end

      it 'handles comparison of string and numeric types' do
        ast = described_class.parse("$[? 13 == '13']")
        expect(ast).to eq("$[?(13 == '13')]")
      end

      it 'handles comparison of number and name selector on root' do
        ast = described_class.parse('$[? 1 <= $.arr]')
        expect(ast).to eq('$[?(1 <= $.arr)]')
      end

      it 'handles numeric comparison with greater-than against a fractional number' do
        ast = described_class.parse('$[? 1 > 2.5]')
        expect(ast).to eq('$[?(1 > 2.5)]')
      end

      it 'parses a union of filter selectors' do
        ast = described_class.parse('$.o[?@<3, ?@<3]')
        expect(ast).to eq('$.o[?(@ < 3), ?(@ < 3)]')
      end

      it 'parses a union of three filter selectors' do
        ast = described_class.parse('$.o[?@<3, ?@<3, ?@<3]')
        expect(ast).to eq('$.o[?(@ < 3), ?(@ < 3), ?(@ < 3)]')
      end

      it 'handles numeric comparison with positive exponent' do
        ast = described_class.parse('$[? 1 <= 5e+2]')
        expect(ast).to eq('$[?(1 <= 500.0)]')
      end

      it 'handles numeric comparison with negative exponent' do
        ast = described_class.parse('$[? 1 <= 5e-2]')
        expect(ast).to eq('$[?(1 <= 0.05)]')
      end

      # CTS "filter, non-singular query in comparison, all children"
      it 'raises error when a comparison operator gets a non-singular-query expression' do
        expect {
          described_class.parse('$[?@[*]==0]')
        }.to raise_error(StandardError, /Expression.* does not produce a singular value/)
      end

      # CTS "filter, literal true must be compared",
      it 'raises error when a boolean literal is the entire condition' do
        expect {
          described_class.parse('$[? true]')
        }.to raise_error(Error, /Literal value .* must be used within a comparison/)
      end
    end
  end
end
