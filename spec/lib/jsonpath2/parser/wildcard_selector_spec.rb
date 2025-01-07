# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_wildcard_selector' do
      it 'parses wildcard selector' do
        ast = described_class.parse('$[*]')
        expect(ast).to eq('$.*')
      end

      it 'parses unioned wildcard selectors' do
        ast = described_class.parse('$.o[*, *]')
        expect(ast).to eq('$.o[*, *]')
      end

      it 'parses dotted name selector after wildcard' do
        ast = described_class.parse('$[? @.*.price >= 5]')
        expect(ast.to_s).to eq('$[?(@.*.price >= 5)]')
      end
    end
  end
end
