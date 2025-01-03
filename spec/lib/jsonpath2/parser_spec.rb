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

    it 'parses bracket notation with empty path' do
      ast = described_class.parse('$[]')
      expect(ast.to_s).to eq('$[]')
    end

    it 'parses dot notation with wildcard selector' do
      ast = described_class.parse('$.*[1]')
      expect(ast.to_s).to eq('$*[1]')
    end

    it 'parses null' do
      ast = described_class.parse('$[?@.a==null]')
      expect(ast.to_s).to eq('$[?(@.a == null)]')
    end
  end
end
