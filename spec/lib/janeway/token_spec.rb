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

    describe '#column_of' do
      def string_token(query)
        Lexer.lex(query).find { |token| token.type == :string }
      end

      it 'returns the column in the query of a character of the decoded value' do
        expect(string_token('$["abc"]').column_of(2)).to eq(5)
        expect(string_token("$['abc']").column_of(2)).to eq(5)
      end

      it 'counts escapes and multibyte characters as one character' do
        {
          %($['it\\'s']) => [3, 7], '$["a\\"b"]' => [2, 6], '$["a\\\\b"]' => [2, 6], '$["a\\tb"]' => [2, 6],
          '$["a\\u00e9b"]' => [2, 10], '$["a\\ud83d\\ude00b"]' => [2, 16], '$["aéb"]' => [2, 5],
          '$["a😀b"]' => [2, 5],
        }.each do |query, (index, col)|
          expect(string_token(query).column_of(index)).to eq(col)
        end
      end

      it 'points at the character or at the backslash that starts its escape' do
        ['$["aé😀b"]', '$["a\\tb\\\\c"]', '$["x\\uD83D\\uDE00y"]', %($['a\\'b'])].each do |query|
          token = string_token(query)
          token.literal.each_char.with_index do |char, index|
            expect([char, '\\']).to include(query[token.column_of(index)])
          end
        end
      end

      it 'is nil for an index past the end of the string' do
        expect(string_token('$["ab"]').column_of(2)).to be_nil
      end

      it 'is nil for a negative index' do
        expect(string_token('$["ab"]').column_of(-1)).to be_nil
      end

      it 'is nil for a token that is not a string' do
        expect(Lexer.lex('$.a').find { |token| token.type == :dot }.column_of(0)).to be_nil
      end
    end

    describe '#location_of' do
      def string_token(query)
        Lexer.lex(query).find { |token| token.type == :string }
      end

      it 'covers the characters of a literal that has no escapes' do
        ['$["abcdef"]', "$['abcdef']", '$["aé😀bcd"]'].each do |query|
          token = string_token(query)
          loc = token.location_of(1, 3)
          expect(query[loc.col, loc.length]).to eq(token.literal[1, 3])
        end
      end

      it 'defaults the length to 1, and treats nil or non-positive as 1' do
        token = string_token('$["abc"]')
        locations = [token.location_of(1), token.location_of(1, nil), token.location_of(1, 0), token.location_of(1, -2)]
        locations.each do |loc|
          expect(loc.col).to eq(4)
          expect(loc.length).to eq(1)
        end
      end

      it 'spans the source text of the characters when there are escapes' do
        # decoded: a, tab, b, e-acute, c
        query = '$["a\\tb\\u00e9c"]'
        loc = string_token(query).location_of(1, 3)
        # from the backslash of \t to the backslash of é, the start of the last character
        expect(query[loc.col, loc.length]).to eq('\\tb\\')
      end

      it 'covers an escaped surrogate pair as the one character it decodes to' do
        query = '$["a\\ud83d\\ude00b"]'
        loc = string_token(query).location_of(1, 1)
        expect(loc.col).to eq(4)
        expect(loc.length).to eq(1)
      end

      it 'returns the location of the token for a nil offset' do
        token = string_token('$["abc"]')
        expect(token.location_of(nil, 1)).to eq(token.location)
      end

      it 'returns the location of the token for an out-of-range offset' do
        token = string_token('$["abc"]')
        expect(token.location_of(3, 1)).to eq(token.location)
        expect(token.location_of(-1, 1)).to eq(token.location)
      end

      it 'returns the location of the token for a range that runs off the end' do
        token = string_token('$["abc"]')
        expect(token.location_of(1, 5)).to eq(token.location)
      end

      it 'returns the location of the token for a token that is not a string' do
        token = Lexer.lex('$.a').find { |t| t.type == :dot }
        expect(token.location_of(0, 1)).to eq(token.location)
      end
    end
  end
end
