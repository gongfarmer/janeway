# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    it 'supports 2 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2]')
      ast = described_class.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new([AST::IndexSelector.new(1), AST::IndexSelector.new(2)])]
      )
    end

    it 'supports 3 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2, 3]')
      ast = described_class.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new([AST::IndexSelector.new(1), AST::IndexSelector.new(2), AST::IndexSelector.new(3)])]
      )
    end

    it 'allows a wildcard selector after a dot' do
      tokens = Lexer.lex('$[?@.*]')
      ast = described_class.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new([AST::FilterSelector.new(AST::CurrentNode.new(AST::WildcardSelector.new))])]
      )
    end

    it 'parses bracketed name selectors with names containing spaces or dots' do
      ast = described_class.parse("$.o['j j']['k.k']")
      expect(ast.to_s).to eq("$.o['j j']['k.k']")
    end
  end
end
