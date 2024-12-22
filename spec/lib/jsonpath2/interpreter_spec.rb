# frozen_string_literal: true

require 'jsonpath2'

module JsonPath2
  describe Interpreter do
    describe '#interpret_array_slice_selector' do
      let(:query) { '$[6:12:2]' }
      let(:tokens) { JsonPath2::Lexer.lex(query) }
      let(:ast) { JsonPath2::Parser.new(tokens).parse }
      let(:input) { ('a'..'g').to_a }
      subject { described_class.new(input) }

      context 'for slice with default step' do
        let(:query) { '$[1:3]' }
        it 'counts by 1' do
          result = subject.interpret(ast)
          expect(result).to eq(%w[b c])
        end
      end
      context 'for slice with no end index' do
        let(:query) { '$[5:]' }
        it 'counts to end' do
          result = subject.interpret(ast)
          expect(result).to eq(%w[f g])
        end
      end
      context 'for slice with step 2' do
        let(:query) { '$[1:5:2]' }
        it 'counts by 2' do
          result = subject.interpret(ast)
          expect(result).to eq(%w[b d])
        end
      end
      context 'for slice with negative step' do
        let(:query) { '$[5:1:-2]' }
        it 'counts backwards by 2' do
          result = subject.interpret(ast)
          expect(result).to eq(%w[f d])
        end
      end
      context 'for slice without start/end and negative step' do
        let(:query) { '$[::-1]' }
        it 'finds all elements in reverse order' do
          result = subject.interpret(ast)
          expect(result).to eq(('g'..'a').to_a)
        end
      end
    end
  end
end
