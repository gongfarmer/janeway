# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_filter_selector' do
      let(:query) { '$[?@.price < 10]' }

      it 'parses a filter selector with a boolean true' do
        ast = described_class.parse('$[? true]')
        expect(ast).to eq('$[?true]')
      end

      it 'parses a filter selector with a boolean false' do
        ast = described_class.parse('$[? false]')
        expect(ast).to eq('$[?false]')
      end

      it 'parses a filter selector with an "or" expression' do
        ast = described_class.parse('$[? false || true]')
        expect(ast).to eq('$[?(false || true)]')
      end

      it 'parses a filter selector with chained "or" expressions' do
        ast = described_class.parse('$[? false || false || true]')
        expect(ast).to eq('$[?((false || false) || true)]')
      end

      it 'parses a filter selector with an "and" expression' do
        ast = described_class.parse('$[? false && true]')
        expect(ast).to eq('$[?(false && true)]')
      end

      it 'parses a filter selector with chained "and" expressions' do
        ast = described_class.parse('$[? false && false && true]')
        expect(ast).to eq('$[?((false && false) && true)]')
      end

      it 'parses a filter selector with chained "or" and "and" expressions' do
        ast = described_class.parse('$[? false || false && true]')
        expect(ast).to eq('$[?(false || (false && true))]')
      end

      it 'parses a filter selector with chained "and" and "or" expressions' do
        ast = described_class.parse('$[? false && false || true]')
        expect(ast).to eq('$[?((false && false) || true)]')
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

      it 'handles comparison of booleans' do
        ast = described_class.parse('$[? true <= true]')
        expect(ast).to eq('$[?(true <= true)]')
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
    end
  end
end
