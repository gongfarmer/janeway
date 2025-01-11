# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Parser do
    it 'supports 2 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2]')
      ast = described_class.new(tokens).parse
      expect(ast.to_s).to eq('$[1, 2]')
    end

    it 'supports 3 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2, 3]')
      ast = described_class.new(tokens).parse
      expect(ast.to_s).to eq('$[1, 2, 3]')
    end

    it 'allows a wildcard selector after a dot' do
      tokens = Lexer.lex('$[?@.*]')
      ast = described_class.new(tokens).parse
      expect(ast.to_s).to eq('$[?@.*]')
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
      expect {
        described_class.parse('$[0,]')
      }.to raise_error(Parser::Error, 'Comma must be followed by another expression in filter selector')
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

    # CTS "basic, name shorthand, number"
    it 'raises error when number follows dot' do
      err = 'Dot "." begins a name selector, and must be followed by an object member name, "1" is invalid here'
      expect {
        described_class.parse('$.1')
      }.to raise_error(Error, err)
    end

    # CTS "basic, multiple selectors, space instead of comma"
    it 'raises error when query contains space separated selectors' do
      expect {
        described_class.parse('$[0 2]')
      }.to raise_error(Error, 'Unexpected character "2" within brackets')
    end

    # CTS "basic, selector, leading comma"
    it 'raises error when child segment starts with comma' do
      expect {
        described_class.parse('$[,0]')
      }.to raise_error(Error, 'Expect selector, got ","')
    end

    # CTS "basic, bald descendant segment"
    it 'raises error when descendant segment is not followed by anything' do
      expect {
        described_class.parse('$..')
      }.to raise_error(Error, 'Descendant segment ".." must be followed by selector')
    end

    # CTS "filter, equals number, invalid double minus"
    it 'raises error when numeric comparison includes double minus' do
      expect {
        described_class.parse('$[?@.a==--1]')
      }.to raise_error(Error, 'Minus operator "-" must be followed by number, got "-"')
    end

    # CTS "filter, equals number, invalid no int digit"
    it 'raises error when fractional number begins with decimal point' do
      expect {
        described_class.parse('$[?@.a==.1]')
      }.to raise_error(Error, 'Decimal point must be preceded by number, got ".1"')
    end

    # CTS "functions, count, no params"
    it 'raises error when count() function call has no parameters' do
      expect {
        described_class.parse('$[?count()==1]')
      }.to raise_error(Error, 'Function call is missing parameter')
    end

    # CTS "functions, count, too many params"
    it 'raises error when count() function call has too many parameters' do
      expect {
        described_class.parse('$[?count(@.a,@.b)==1]')
      }.to raise_error(Error, 'Too many parameters for count() function call')
    end

    # CTS "functions, length, too many params"
    it 'raises error when length() function call has too many parameters' do
      expect {
        described_class.parse('$[?length(@.a,@.b)==1]')
      }.to raise_error(Error, 'Too many parameters for length() function call')
    end

    # CTS "functions, match, too few params"
    it 'raises error when function call has no parameters' do
      expect {
        described_class.parse('$[?match(@.a)==1]')
      }.to raise_error(Error, 'Not enough parameters for match() function call')
    end

    # CTS "functions, match, too many params"
    it 'raises error when match() function call has too many parameters' do
      expect {
        described_class.parse('$[?match(@.a,@.b,@.c)==1]')
      }.to raise_error(Error, 'Too many parameters for match() function call')
    end

    # CTS "functions, search, too few params"
    it 'raises error when search() function call has no parameters' do
      expect {
        described_class.parse('$[?search(@.a)]')
      }.to raise_error(Error, 'Insufficient parameters for search() function call')
    end

    # CTS "functions, search, too many params"
    it 'raises error when search() function call has no parameters' do
      expect {
        described_class.parse('$[?search(@.a,@.b,@.c)]')
      }.to raise_error(Error, 'Too many parameters for match() function call')
    end

    # CTS "functions, value, too many params"
    it 'raises error when search() function call has no parameters' do
      expect {
        described_class.parse('$[?value(@.a,@.b)==4]')
      }.to raise_error(Error, 'Too many parameters for value() function call')
    end

    it 'parses name selector with shorthand notation following a descendant segment' do
      tokens = Lexer.lex('$..nodes..more')
      ast = described_class.new(tokens).parse
      expect(ast.to_s).to eq('$..nodes..more')
    end

    it 'parses a descendant segment following a name selector' do
      tokens = Lexer.lex('$.nodes..["services"]..["id"]')
      ast = described_class.new(tokens).parse
      expect(ast.to_s).to eq('$.nodes..services..id')
    end
  end
end
