# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_filter_selector' do
      let(:query) { '$[?@.price < 10]' }

      it 'parses a filter selector with a boolean true' do
        ast = described_class.parse('$[? true]')
        expect(ast).to eq('$[? true]')
      end

      it 'parses a filter selector with a boolean false' do
        ast = described_class.parse('$[? false]')
        expect(ast).to eq('$[? false]')
      end

      it 'parses a filter selector with an "or" expression' do
        ast = described_class.parse('$[? false || true]')
        expect(ast).to eq('$[? (false || true)]')
      end

      it 'parses a filter selector with chained "or" expressions' do
        ast = described_class.parse('$[? false || false || true]')
        expect(ast).to eq('$[? ((false || false) || true)]')
      end

      it 'parses a filter selector with an "and" expression' do
        ast = described_class.parse('$[? false && true]')
        expect(ast).to eq('$[? (false && true)]')
      end

      it 'parses a filter selector with chained "and" expressions' do
        ast = described_class.parse('$[? false && false && true]')
        expect(ast).to eq('$[? ((false && false) && true)]')
      end

      it 'parses a filter selector with chained "or" and "and" expressions' do
        ast = described_class.parse('$[? false || false && true]')
        expect(ast).to eq('$[? (false || (false && true))]')
      end

      it 'parses a filter selector with chained "and" and "or" expressions' do
        ast = described_class.parse('$[? false && false || true]')
        expect(ast).to eq('$[? ((false && false) || true)]')
      end

      it 'parses current node operator' do
        ast = described_class.parse('$[? @.key1 == true]')
        expect(ast).to eq('$[? (@.key1 == true)]')
      end

      ### Examples from https://www.rfc-editor.org/rfc/rfc9535.html#name-examples-6

      it 'handles equality operator with nodelists' do
        ast = described_class.parse('$[? $.absent1 == $.absent2]')
        expect(ast).to eq('$[? ($.absent1 == $.absent2)]')
      end

      it 'handles less than or equal to operator' do
        ast = described_class.parse('$[? $.absent1 <= $.absent2]')
        expect(ast).to eq('$[? ($.absent1 <= $.absent2)]')
      end
    end
  end
end
