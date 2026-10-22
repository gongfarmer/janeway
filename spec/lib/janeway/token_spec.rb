# frozen_string_literal: true

require 'janeway/token'
require 'janeway/location'
require 'janeway/lexer'

module Janeway
  describe Token do
    let(:location) { Location.new(0, 1) }

    describe '#==' do
      it 'returns true when comparing two tokens with the same type, lexeme, and literal' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '1', 1, location)
        expect(t1 == t2).to be(true)
      end

      it 'returns false when comparing two tokens with different type' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:string, '1', 1, location)
        expect(t1 == t2).to be(false)
      end

      it 'returns false when comparing two tokens with different lexeme' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '2', 1, location)
        expect(t1 == t2).to be(false)
      end

      it 'returns false when comparing two tokens with different literal' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '1', 2, location)
        expect(t1 == t2).to be(false)
      end

      it 'does not mutate self when comparing two tokens with different literal' do
        t1 = described_class.new(:number, '1', 1, location)
        t2 = described_class.new(:number, '1', 2, location)
        t1 == t2
        expect(t1.literal).to eq(1)
      end

      it 'compares literal when other is an Integer' do
        t = described_class.new(:number, '1', 1, location)
        expect(t == 1).to be(true)
        expect(t == 2).to be(false)
      end

      it 'compares literal when other is a String' do
        t = described_class.new(:string, '"foo"', 'foo', location)
        expect(t == 'foo').to be(true)
        expect(t == 'bar').to be(false)
      end

      it 'compares type when other is a Symbol' do
        t = described_class.new(:number, '1', 1, location)
        expect(t == :number).to be(true)
        expect(t == :string).to be(false)
      end
    end

    describe '#offsets' do
      # @param query [String] query with one string token
      def token_in(query)
        Lexer.lex(query).find { |token| token.type == :string }
      end

      # column in the query of the character at index in the token's decoded value
      def column_of(query, index)
        token = token_in(query)
        token.location.col + token.offsets[index]
      end

      it 'has one offset for each character of the decoded value' do
        ['$["abc"]', %($['it\\'s']), '$["a\\tb"]', '$["a\\ud83d\\ude00b"]', '$["aé😀b"]'].each do |query|
          token = token_in(query)
          expect(token.offsets.length).to eq(token.literal.length)
        end
      end

      it 'maps an index in a double-quoted string' do
        expect(column_of('$["abc"]', 2)).to eq(5)
      end

      it 'maps an index in a single-quoted string' do
        expect(column_of("$['abc']", 2)).to eq(5)
      end

      it 'counts an escaped quote as one character' do
        # decoded value is it's, query text is 'it\'s'
        expect(column_of("$['it\\'s']", 3)).to eq(7)
      end

      it 'counts an escaped double quote as one character' do
        expect(column_of('$["a\\"b"]', 2)).to eq(6)
      end

      it 'counts an escaped backslash as one character' do
        expect(column_of('$["a\\\\b"]', 2)).to eq(6)
      end

      it 'counts a short escape as one character' do
        expect(column_of('$["a\\tb"]', 2)).to eq(6)
      end

      it 'counts a \\uXXXX escape as one character' do
        expect(column_of('$["a\\u00e9b"]', 2)).to eq(10)
      end

      it 'counts an escaped surrogate pair as one character' do
        expect(column_of('$["a\\ud83d\\ude00b"]', 2)).to eq(16)
      end

      it 'counts a multibyte character as one character' do
        expect(column_of('$["aéb"]', 2)).to eq(5)
      end

      it 'counts an emoji as one character' do
        expect(column_of('$["a😀b"]', 2)).to eq(5)
      end

      # Each case is a string literal as written in a query. The column of every decoded character must be
      # a position in the query that holds either that character or the backslash that starts its escape.
      [
        "''", '""', %('\\n'), %('\\b\\f\\n\\r\\t'), %("\\/"), %("a\\/b"), %("\\u00E9"), %("\\u00e9"),
        %("\\uD83D\\uDE00"), %("x\\uD83D\\uDE00y"), %("\\\\"), %("a\\"b"), %('a\\'b'),
      ].each do |literal|
        it "locates every character of #{literal}" do
          query = "$[#{literal}]"
          token = token_in(query)
          expect(token.offsets.length).to eq(token.literal.length)
          token.literal.each_char.with_index do |char, index|
            col = column_of(query, index)
            expect([char, '\\']).to include(query[col])
          end
        end
      end

      it 'has no offset for an index past the end of the string' do
        expect(token_in('$["ab"]').offsets[2]).to be_nil
      end

      it 'is nil for a token that is not a string' do
        expect(Lexer.lex('$.a').find { |token| token.type == :dot }.offsets).to be_nil
      end
    end
  end
end
