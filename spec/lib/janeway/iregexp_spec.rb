# frozen_string_literal: true

require 'janeway'
require 'janeway/iregexp'

module Janeway
  # The accepts and rejects helpers define the examples, which rubocop-rspec cannot see.
  # rubocop: disable RSpec/EmptyExampleGroup
  describe IRegexp do
    describe '.compile' do
      # @param pattern [String] I-Regexp
      # @param matching [Array<String>] strings that must match
      # @param not_matching [Array<String>] strings that must not match
      def self.accepts(pattern, matching, not_matching = [], anchor: true)
        it "accepts #{pattern.inspect}" do
          regexp = described_class.compile(pattern, anchor: anchor)
          expect(matching.grep_v(regexp)).to be_empty
          expect(not_matching.grep(regexp)).to be_empty
        end
      end

      def self.rejects(pattern, error_class, offset: :any)
        it "rejects #{pattern[0, 30].inspect} with #{error_class.name.split('::').last}" do
          expect { described_class.compile(pattern) }.to raise_error(error_class) { |error|
            expect(error.offset).to eq(offset) unless offset == :any
          }
        end
      end

      context 'with characters that Ruby treats as syntax but I-Regexp does not' do
        # RFC 9485 section 3: NormalChar includes "$" and "^", they are not anchors
        accepts 'a$b', ['a$b'], ['ab']
        accepts '^s', ['^s'], %w[s sparrow]
        accepts 'a^', ['a^'], ['a']
        # RFC 9485 section 3: "^" negates a character class only at the start of it
        accepts '[^a]', ['b'], ['a']
        accepts '[a^]', %w[a ^], ['b']
        accepts '[a&&b]', %w[a & b]
        accepts '[&&]', ['&']
      end

      context 'with the dot' do
        # RFC 9485 section 5.4: an unescaped dot outside a character class matches [^\n\r]
        accepts 'a.c', ['abc', "a\u2028c"], ["a\nc", "a\rc"]
        accepts 'a[.]c', ['a.c'], ['abc']
        accepts 'a\\.c', ['a.c'], ['abc']
        accepts 'a\\\\.c', ['a\\bc'], ['a.c']
      end

      context 'with escapes' do
        accepts '\\n', ["\n"]
        accepts '\\t', ["\t"]
        accepts 'a\\{b{2}', ['a{bb']
        accepts '[\\]]', [']']
        accepts '[\\\\]', ['\\']
        accepts '\\p{Lu}', ['A'], ['a']
        accepts '\\P{Lu}', ['a'], ['A']
        accepts '\\p{L}\\p{Nd}', ['a1']
        accepts '[\\p{L}\\p{N}]', %w[a 1], ['-']
      end

      context 'with character classes' do
        accepts '[-a]', %w[- a]
        accepts '[a-]', %w[- a]
        accepts '[a-c]', ['b'], ['d']
        accepts '[a-cx-z]', %w[b y], ['d']
        accepts '[^-a]', ['b'], %w[- a]
        # RFC 9485 section 3: a SingleCharEsc is a CCchar, so it can start or end a range
        accepts '[\\n-z]', %W[a 0 \n z], ['{']
        accepts '[\\(-\\)]', %w[( )], ['*']
        accepts '[\\]-\\^]', [']', '^'], ['a', '\\']
        accepts '[\\--z]', %w[a -]
      end

      context 'with alternation, groups and quantifiers' do
        accepts 'a|', ['a', ''], ['b']
        accepts '()', ['']
        accepts '(ab)+', %w[ab abab], ['a']
        accepts 'a?', ['', 'a']
        accepts 'a{2}', ['aa'], %w[a aaa]
        accepts 'a{2,}', %w[aa aaa], ['a']
        accepts 'a{2,3}', %w[aa aaa], %w[a aaaa]
        accepts 'a{0}', ['']
        accepts 'a,b-c', ['a,b-c']
        accepts 'é', ['é']
        accepts 'a', %w[xay a], ['b'], anchor: false
      end

      context 'with a pattern that is not an I-Regexp' do
        rejects '(a)\\1', IRegexp::Invalid
        rejects '(?=a)a', IRegexp::Invalid, offset: 1
        rejects '(?i)a', IRegexp::Invalid, offset: 1
        rejects '(?<n>a)', IRegexp::Invalid
        rejects 'a+?', IRegexp::Invalid, offset: 2
        rejects 'a*+', IRegexp::Invalid, offset: 2
        rejects 'a**', IRegexp::Invalid
        rejects '\\d', IRegexp::Invalid, offset: 0
        rejects '\\w', IRegexp::Invalid
        rejects '\\$', IRegexp::Invalid
        rejects '[^]', IRegexp::Invalid, offset: 0
        rejects '[a', IRegexp::Invalid, offset: 2
        rejects '[', IRegexp::Invalid
        rejects '[[]', IRegexp::Invalid
        rejects '[a-]b-]', IRegexp::Invalid
        rejects '[z-a]', IRegexp::Invalid
        # RFC 9485 section 3: charClassEsc is not a CCchar, so it cannot be a range endpoint
        rejects '[a-\\p{L}]', IRegexp::Invalid
        rejects '[\\p{L}-a]', IRegexp::Invalid
        rejects '[\\p{Lu}-\\p{Ll}]', IRegexp::Invalid
        # valid per the grammar, but an empty range, which Ruby refuses (RegexpError)
        rejects '[a-\\n]', IRegexp::Invalid
        rejects '[\\n-\\t]', IRegexp::Invalid
        rejects '(a', IRegexp::Invalid, offset: 2
        rejects 'a)', IRegexp::Invalid, offset: 1
        rejects '\\p{Foo}', IRegexp::Invalid, offset: 0
        rejects '\\p{L', IRegexp::Invalid
        rejects 'a\\', IRegexp::Invalid
        rejects 'a{', IRegexp::Invalid, offset: 1
        rejects 'a{2', IRegexp::Invalid, offset: 1
        rejects 'a{,2}', IRegexp::Invalid
        rejects '{2}', IRegexp::Invalid
        rejects 'a{b{1001}', IRegexp::Invalid, offset: 1
        rejects '*', IRegexp::Invalid
        rejects "a\xff", IRegexp::Invalid
        # valid per the grammar, but Ruby refuses it
        rejects 'a{3,2}', IRegexp::Invalid
      end

      context 'with a pattern that is over a limit' do
        rejects 'a{1001}', IRegexp::LimitExceeded, offset: 2
        rejects 'a{1,1001}', IRegexp::LimitExceeded, offset: 4
        rejects 'a{1001,}', IRegexp::LimitExceeded, offset: 2
        rejects 'a\\{b{1001}', IRegexp::LimitExceeded, offset: 5
        rejects 'a' * 10_001, IRegexp::LimitExceeded, offset: nil
        rejects "#{'(' * 101}#{')' * 101}", IRegexp::LimitExceeded, offset: 100
        # a range quantifier applied to a group that contains a range quantifier
        rejects '(a{2}){2}', IRegexp::LimitExceeded, offset: 6
        rejects '((a{2})){2}', IRegexp::LimitExceeded
        rejects '(a{2}b){2,3}', IRegexp::LimitExceeded
        rejects '((a{2})*){2}', IRegexp::LimitExceeded
        rejects '(a{2})(b{2}){2}', IRegexp::LimitExceeded

        accepts 'a{1000}', ['a' * 1000]
        accepts 'a{1,1000}', ['a']
        accepts "#{'a' * 9_999}b", ["#{'a' * 9_999}b"]
        accepts "#{'(' * 100}#{')' * 100}", ['']
        # a quantifier after a group applies to the group, not to the atom that follows it
        accepts '(a{2})\\.{2}', ['aa..'], ['aa.']
        accepts '(a{2})\\p{L}{2}', ['aaxy']
        accepts '(a{2})[xy]{2}', ['aaxy']
        accepts '(a{2})b{2}', ['aabb']
        accepts '(a{2})(b{2})', ['aabb']
        accepts '(a{2})*', ['', 'aaaa'], ['aaa']
        accepts '(a{2})+', ['aa']
        # \p{L} contains braces but is not a range quantifier
        accepts '(\\p{L}){2}', ['ab']
        accepts '(\\P{Lu}){2}', ['ab']
        accepts '(\\p{L}\\p{N}){2,3}', ['a1b2']
      end

      context 'when a pattern is both not an I-Regexp and over a limit' do
        # the grammar is checked first, so this is reported as Invalid
        rejects 'a{1001}(', IRegexp::Invalid
        rejects '(a{2}){2}(', IRegexp::Invalid
        rejects "#{'a' * 10_001}(", IRegexp::Invalid
      end

      it 'does not overflow the stack on deeply nested groups' do
        expect { described_class.compile('(' * 9_000) }.to raise_error(IRegexp::LimitExceeded)
      end

      it 'reports the number of characters that a limit error covers' do
        expect { described_class.compile('a{12345}') }.to raise_error(IRegexp::LimitExceeded) { |error|
          expect([error.offset, error.length]).to eq([2, 5])
        }
      end

      it 'raises errors that are Janeway::Error' do
        expect { described_class.compile('(') }.to raise_error(Janeway::Error)
        expect { described_class.compile('a{1001}') }.to raise_error(Janeway::Error)
      end

      it 'limits how long a match may take', skip: (IRegexp::TIMEOUT_SUPPORTED ? false : 'needs Ruby 3.2') do
        expect(described_class.compile('a').timeout).to eq(IRegexp::MATCH_TIMEOUT)
      end
    end

    describe '.query_column' do
      # @param query [String] query with one string token
      def token_in(query)
        Lexer.lex(query).find { |token| token.type == :string }
      end

      def column_of(query, index)
        described_class.query_column(token_in(query), index)
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

      it 'returns nil for an index past the end of the string' do
        expect(column_of('$["ab"]', 2)).to be_nil
      end
    end
  end
  # rubocop: enable RSpec/EmptyExampleGroup
end
