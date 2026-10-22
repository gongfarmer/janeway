# frozen_string_literal: true

require 'json'
require 'janeway'

# Examples from https://www.rfc-editor.org/rfc/rfc9535.html#section-2.3.5.3-8
module Janeway
  # rubocop: disable RSpec/ExampleLength
  describe Interpreter do
    describe '#interpret_filter_selector' do
      let(:input) do
        JSON.parse(<<~JSON_STRING)
          {
            "a": [3, 5, 1, 2, 4, 6,
                  {"b": "j"},
                  {"b": "k"},
                  {"b": {}},
                  {"b": "kilo"}
                 ],
            "o": {"p": 1, "q": 2, "r": 3, "s": 5, "t": {"u": 6}},
            "e": "abcdef"
          }
        JSON_STRING
      end

      describe 'jsonpath function "length"' do
        let(:input) { %w[a ab abc abcd] }

        it 'gets the length of a string' do
          expect(described_class.interpret(input, '$[? length(@) == 3]')).to eq(['abc'])
        end

        it 'gets the number of elements in an array' do
          input = [
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4],
            [1, 2, 3],
          ]
          expect(described_class.interpret(input, '$[?(length(@) == 4)]')).to eq([[1, 2, 3, 4]])
        end

        it 'gets the number of members in a hash' do
          input = [
            { a: 1 },
            { a: 1, b: 2 },
            { a: 1, b: 2, c: 3 },
          ]
          expect(described_class.interpret(input, '$[?(length(@) == 2)]')).to eq([{ a: 1, b: 2 }])
        end

        it 'returns Nothing if the input is not a string, array or hash' do
          input = [1, 2, 3]
          expect(described_class.interpret(input, '$[? length(@) == 3]')).to eq([])
        end

        it 'returns empty result when given bad parameter that is a number' do
          expect(described_class.interpret(input, '$[?(length(4) == 4)]')).to be_empty
        end

        it 'returns empty result when given bad parameter that is a boolean' do
          expect(described_class.interpret(input, '$[?(length(true) == 4)]')).to be_empty
        end

        it 'returns empty result when given bad parameter that is a null' do
          expect(described_class.interpret(input, '$[?(length(null) == 4)]')).to be_empty
        end

        # CTS "functions, length, arg is a function expression"
        it 'can use the return from a ValueType function as a parameter' do
          query = '$.values[?length(@.a)==length(value($..c))]'
          input = { 'c' => 'cd', 'values' => [{ 'a' => 'ab' }, { 'a' => 'd' }] }
          expect(described_class.interpret(input, query)).to eq([{ 'a' => 'ab' }])
        end
      end

      describe 'jsonpath function "count"' do
        it 'returns 1 when applied to any string' do
          input = %w[a ab abc abcd]
          expect(described_class.interpret(input, '$[? count(@) == 1]')).to eq(input)
        end

        it 'gets the number of elements in an array' do
          input = [
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4],
            [1, 2, 3],
          ]
          expect(described_class.interpret(input, '$[?(count(@) == 4)]')).to eq([[1, 2, 3, 4]])
        end

        it 'returns 1 when applied to any hash' do
          input = [
            { a: 1 },
            { a: 1, b: 2 },
            { a: 1, b: 2, c: 3 },
          ]
          expect(described_class.interpret(input, '$[?(count(@) == 1)]')).to eq(input)
        end
      end

      describe 'jsonpath function "match"' do
        it 'supports regular expression match of array values' do
          # entire string match
          result = described_class.interpret(input, '$.a[?match(@.b, "[jk]")]')
          expect(result).to eq([{ 'b' => 'j' }, { 'b' => 'k' }])
        end

        # CTS "functions, match, regex from the document",
        it 'reads iregexp from the input document' do
          query = '$.values[?match(@, $.regex)]'
          input =
            {
              'regex' => 'b.?b',
              'values' => ['abc', 'bcd', 'bab', 'bba', 'bbab', 'b', true, [], {}],
            }
          expected = ['bab']
          expect(described_class.interpret(input, query)).to eq(expected)
        end

        it 'accepts a range quantifier' do
          input = %w[1 12 123 1234 12345]
          result = described_class.interpret(input, '$[?match(@, "[0-9]{2,4}")]')
          expect(result).to eq(%w[12 123 1234])
        end

        it 'rejects a literal range quantifier with a large bound' do
          expect {
            described_class.interpret([], '$[?match(@, "a{20,200000}")]')
          }.to raise_error(Janeway::Error, /repeat count 200000/)
        end

        # RFC 9535 section 2.4.6: a pattern that does not conform to RFC 9485 gives LogicalFalse
        it 'selects nothing for a literal pattern that is not an I-Regexp' do
          expect(described_class.interpret(%w[a aa], '$[?match(@, "(?=a)a")]')).to eq([])
        end

        it 'selects nothing for a pattern from the input document that is not an I-Regexp' do
          input = { 'regex' => '(a)\\1', 'values' => %w[aa a] }
          expect(described_class.interpret(input, '$.values[?match(@, $.regex)]')).to eq([])
        end

        it 'selects nothing for a pattern from the input document that is over a limit' do
          input = { 'regex' => 'a{20,200000}', 'values' => ['aaa'] }
          expect(described_class.interpret(input, '$.values[?match(@, $.regex)]')).to eq([])
        end

        it 'still uses the good patterns when another pattern in the document is bad' do
          input = { 'regexes' => ['(?=a)a', 'a+'], 'values' => ['aa'] }
          result = described_class.interpret(input, '$.regexes[?match($.values[0], @)]')
          expect(result).to eq(['a+'])
        end

        # RFC 9485 section 3: ^ and $ are ordinary characters, not anchors
        it 'treats ^ and $ in a pattern as ordinary characters' do
          input = ['a$b', 'ab', '^s', 'sparrow']
          expect(described_class.interpret(input, '$[?match(@, "a$b")]')).to eq(['a$b'])
          expect(described_class.interpret(input, '$[?search(@, "^s")]')).to eq(['^s'])
        end

        it 'does not treat && in a character class as an intersection' do
          expect(described_class.interpret(%w[a & b c], '$[?match(@, "[a&&b]")]')).to eq(%w[a & b])
        end

        it 'skips a string that is not valid UTF-8 and keeps matching the others' do
          input = ["a\xff".b.force_encoding('UTF-8'), 'a']
          expect(described_class.interpret(input, '$[?search(@, "a")]')).to eq(['a'])
        end

        it 'gives false for a document pattern in a string encoding other than UTF-8' do
          [
            'a'.encode('UTF-16LE'),
            "caf\xE9".dup.force_encoding('ISO-8859-1'),
            'a'.b,
          ].each do |pattern|
            input = { 'p' => pattern, 'values' => ['a'] }
            expect(described_class.interpret(input, '$.values[?search(@, $.p)]')).to eq([])
          end
        end

        it 'still uses a document pattern that is US-ASCII or multibyte UTF-8' do
          values = %W[a \u00e9\u00e9]
          input = { 'p' => 'a'.dup.force_encoding('US-ASCII'), 'q' => "\u00e9+", 'values' => values }
          expect(described_class.interpret(input, '$.values[?match(@, $.p)]')).to eq(['a'])
          expect(described_class.interpret(input, '$.values[?match(@, $.q)]')).to eq(["\u00e9\u00e9"])
        end

        context 'when a match times out' do
          let(:regexp) { instance_double(Regexp) }

          before do
            allow(regexp).to receive(:match?).and_raise(IRegexp::TIMEOUT_ERROR)
            allow(IRegexp).to receive(:compile).and_return(regexp)
          end

          it 'matches a literal pattern only once, then gives false' do
            expect(described_class.interpret(%w[a b c d], '$[?match(@, "x")]')).to eq([])
            expect(regexp).to have_received(:match?).once
          end

          it 'matches a document pattern only once, then gives false' do
            input = { 'p' => 'x', 'values' => %w[a b c d] }
            expect(described_class.interpret(input, '$.values[?search(@, $.p)]')).to eq([])
            expect(regexp).to have_received(:match?).once
          end
        end

        it 'compiles each distinct document pattern once, and compiles an evicted one again' do
          patterns = Array.new(101) { |i| "x#{i}" }
          input = { 'patterns' => patterns, 'first' => 'x0', 'last' => 'x100' }
          allow(IRegexp).to receive(:compile).and_call_original
          result = described_class.interpret(input, '$.patterns[?match($.last, @)]')
          expect(result).to eq(['x100'])
          expect(IRegexp).to have_received(:compile).exactly(101).times
          result = described_class.interpret(input, '$.patterns[?match($.first, @)]')
          expect(result).to eq(['x0'])
        end

        it 'recompiles a pattern after 100 others have pushed it out of the cache' do
          patterns = ['x0'] + Array.new(100) { |i| "y#{i}" } + ['x0']
          input = { 'patterns' => patterns }
          allow(IRegexp).to receive(:compile).and_call_original
          described_class.interpret(input, '$.patterns[?match("x0", @)]')
          expect(IRegexp).to have_received(:compile).with('x0', anchor: true).twice
          expect(IRegexp).to have_received(:compile).exactly(102).times
        end

        it 'compiles a pattern from the input document once per distinct pattern' do
          input = { 'regex' => 'a+', 'values' => %w[a aa aaa b] }
          allow(IRegexp).to receive(:compile).and_call_original
          described_class.interpret(input, '$.values[?match(@, $.regex)]')
          expect(IRegexp).to have_received(:compile).with('a+', anchor: true).once
        end

        # CTS "functions, match, escaped right square bracket"
        it 'can match a regexp with an escaped right square bracket inside a character class' do
          input = ['abc', 'a.c', "a\u2028c", 'a]c']
          result = described_class.interpret(input, "$[?match(@, 'a[\\\\].]c')]")
          expect(result).to eq(['a.c', 'a]c'])
        end
      end

      describe 'jsonpath function "search"' do
        it 'supports regular expression search of array values' do
          # substring match
          result = described_class.interpret(input, '$.a[?search(@.b, "[jk]")]')
          expect(result).to eq([{ 'b' => 'j' }, { 'b' => 'k' }, { 'b' => 'kilo' }])
        end
      end

      # CTS "functions, value, single-value nodelist",
      it 'interprets the value() function' do
        query = '$[?value(@.*)==4]'
        input = [[4], { 'foo' => 4 }, [5], { 'foo' => 5 }, 4]
        expected = [[4], { 'foo' => 4 }]
        expect(described_class.interpret(input, query)).to eq(expected)
      end

      # CTS "filter, equals, special nothing",
      it 'interprets usage of the root node in a function call' do
        query = '$.values[?length(@.a) == value($..c)]'
        input =
          {
            'c' => 'cd',
            'values' => [
              { 'a' => 'ab' },
              { 'c' => 'd' },
              { 'a' => nil },
            ],
          }
        expected = [{ 'c' => 'd' }, { 'a' => nil }]
        expect(described_class.interpret(input, query)).to eq(expected)
      end
    end
  end
  # rubocop: enable RSpec/ExampleLength
end
