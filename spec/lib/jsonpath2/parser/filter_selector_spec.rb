# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Parser do
    describe '#parse_filter_selector' do
      let(:query) { '$[?@.price < 10]' }

      it 'parses a filter selector with a boolean true' do
        ast = described_class.parse('$[? true]')
        expected = AST::FilterSelector.new << true
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with a boolean false' do
        ast = described_class.parse('$[? false]')
        expected = AST::FilterSelector.new << false
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with an "or" expression' do
        ast = described_class.parse('$[? false || true]')
        expected = AST::FilterSelector.new
        expected << AST::BinaryOperator.new(:or, false, true)
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with chained "or" expressions' do
        ast = described_class.parse('$[? false || false || true]')
        expected = AST::FilterSelector.new
        op1 = AST::BinaryOperator.new(:or, false, false)
        op2 = AST::BinaryOperator.new(:or, op1, true)
        expected << op2
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with an "and" expression' do
        ast = described_class.parse('$[? false && true]')
        expected = AST::FilterSelector.new
        expected << AST::BinaryOperator.new(:and, false, true)
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with chained "and" expressions' do
        ast = described_class.parse('$[? false && false && true]')
        expected = AST::FilterSelector.new
        op1 = AST::BinaryOperator.new(:and, false, false)
        op2 = AST::BinaryOperator.new(:and, op1, true)
        expected << op2
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with chained "or" and "and" expressions' do
        ast = described_class.parse('$[? false || false && true]')
        expected = AST::FilterSelector.new
        op1 = AST::BinaryOperator.new(:and, false, true)
        op2 = AST::BinaryOperator.new(:or, false, op1)
        expected << op2
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end

      it 'parses a filter selector with chained "and" and "or" expressions' do
        ast = described_class.parse('$[? false && false || true]')
        expected = AST::FilterSelector.new
        op1 = AST::BinaryOperator.new(:and, false, false)
        op2 = AST::BinaryOperator.new(:or, op1, true)
        expected << op2
        expect(ast.expressions).to eq([AST::Root.new, [expected]])
      end
      # FIXME: These tests are starting to get hard to follow.
      # Would it be clearer to implement `#to_s` on all the AST classes 
      # so that I can compare the top-level expression with a JsonPath string?
    end
  end
end
