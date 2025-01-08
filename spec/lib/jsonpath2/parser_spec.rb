# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    it 'supports 2 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2]')
      ast = described_class.new(tokens).parse
      expect(ast.root).to eq(
        AST::RootNode.new([AST::IndexSelector.new(1), AST::IndexSelector.new(2)])
      )
    end

    it 'supports 3 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2, 3]')
      ast = described_class.new(tokens).parse
      expect(ast.root).to eq(
        AST::RootNode.new([AST::IndexSelector.new(1), AST::IndexSelector.new(2), AST::IndexSelector.new(3)])
      )
    end

    it 'allows a wildcard selector after a dot' do
      tokens = Lexer.lex('$[?@.*]')
      ast = described_class.new(tokens).parse
      expect(ast.root).to eq(
        AST::RootNode.new([AST::FilterSelector.new(AST::CurrentNode.new(AST::WildcardSelector.new))])
      )
    end

    it 'combines the minus sign and number into one node in an index selector' do
      ast = described_class.parse('$[-1]')
      index_selector = ast.root.value
      expect(index_selector.value).to eq(-1)
    end

    it 'parses bracketed name selectors with names containing spaces or dots' do
      ast = described_class.parse("$.o['j j']['k.k']")
      expect(ast.to_s).to eq("$.o['j j']['k.k']")
    end

    it 'parses dot notation with wildcard selector' do
      ast = described_class.parse('$.*[1]')
      expect(ast.to_s).to eq('$.*[1]')
    end

    it 'parses null' do
      ast = described_class.parse('$[?@.a==null]')
      expect(ast.to_s).to eq('$[?(@.a == null)]')
    end

    it 'parses comparison with exponent' do
      ast = described_class.parse('$[?@.a==1e2]')
      expect(ast.to_s).to eq('$[?(@.a == 100.0)]')
    end

    it 'raises error on trailing comma' do
      expect do
        described_class.parse('$[0,]')
      end.to raise_error(Parser::Error, 'Comma must be followed by another expression in filter selector')
    end

    it 'parses child segment that contains a single name selector as just a name selector' do
      # the point is that there is no AST::ChildSegment here that contains the name selector
      tokens = Lexer.lex('$["abc"]')
      ast = described_class.new(tokens).parse
      expect(ast.root.value).to eq(AST::NameSelector.new('abc'))
    end

    it 'applies minus operator to the following zero' do
      # parser is expected to combine the "-" and "0" tokens
      ast = described_class.parse('$[?@.a==-0]')
      equals_operator = ast.root.value.value
      expect(equals_operator.right).to have_attributes(
        class: AST::Number,
        value: 0
      )
    end

    it 'applies minus operator to the following integer' do
      # parser is expected to combine the "-" and number tokens
      ast = described_class.parse('$[?@.a==-1]')
      equals_operator = ast.root.value.value
      expect(equals_operator.right).to have_attributes(
        class: AST::Number,
        value: -1
      )
    end

    it 'applies minus operator to the following float' do
      # parser is expected to combine the "-" and number tokens
      ast = described_class.parse('$[?@.a==-15.8]')
      equals_operator = ast.root.value.value
      expect(equals_operator.right).to have_attributes(
        class: AST::Number,
        value: -15.8
      )
    end
  end
end
