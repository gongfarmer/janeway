# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    it 'supports 2 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2]')
      ast = described_class.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new, [AST::IndexSelector.new(1), AST::IndexSelector.new(2)]]
      )
    end

    it 'supports 3 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2, 3]')
      ast = described_class.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new, [AST::IndexSelector.new(1), AST::IndexSelector.new(2), AST::IndexSelector.new(3)]]
      )
    end
  end
end
