# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Parser do
    describe '#parse_wildcard_selector' do
      it 'parses wildcard selector' do
        ast = described_class.parse('$[*]')
        expect(ast.to_s).to eq('$.*')
      end

      it 'parses unioned wildcard selectors' do
        ast = described_class.parse('$.o[*, *]')
        expect(ast.to_s).to eq('$.o[*, *]')
      end
    end
  end
end
