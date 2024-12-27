# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    let(:query) { '$[1,2]' }
    let(:tokens) { JsonPath2::Lexer.lex(query) }

    it 'supports 2 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2]')
      ast = JsonPath2::Parser.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new, [AST::IndexSelector.new(1), AST::IndexSelector.new(2)]]
      )
    end
    it 'supports 3 comma-separated selectors in one pair of square brackets' do
      tokens = Lexer.lex('$[1, 2, 3]')
      ast = JsonPath2::Parser.new(tokens).parse
      expect(ast.expressions).to eq(
        [AST::Root.new, [AST::IndexSelector.new(1), AST::IndexSelector.new(2), AST::IndexSelector.new(3)]]
      )
    end

    describe '#parse_array_slice_selector' do
      let(:query) { '$[6:12:2]' }
      it 'parses all 3 components' do
        ast = JsonPath2::Parser.new(tokens).parse
        expect(ast.expressions).to eq(
          [AST::Root.new, [AST::ArraySliceSelector.new(6, 12, 2)]]
        )
      end
      it 'defaults to step 1' do
        ast = JsonPath2::Parser.parse('$[6:12]')
        expect(ast.expressions).to eq(
          [AST::Root.new, [AST::ArraySliceSelector.new(6, 12, 1)]]
        )
      end
      it 'ends at the last index if step is positive' do
        ast = JsonPath2::Parser.parse('$[6::1]')
        expect(ast.expressions).to eq(
          [AST::Root.new, [AST::ArraySliceSelector.new(6, -1, 1)]]
        )
      end
      it 'ends at the start index if step is negative' do
        ast = JsonPath2::Parser.parse('$[6::-1]')
        expect(ast.expressions).to eq(
          [AST::Root.new, [AST::ArraySliceSelector.new(6, 0, -1)]]
        )
      end
      it 'iterates from end to start if only negative step is given' do
        ast = JsonPath2::Parser.parse('$[::-1]')
        expect(ast.expressions).to eq(
          [AST::Root.new, [AST::ArraySliceSelector.new(-1, 0, -1)]]
        )
      end
    end
  end
end
