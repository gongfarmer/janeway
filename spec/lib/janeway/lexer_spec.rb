# frozen_string_literal: true

require 'janeway/lexer'

module Janeway
  describe Lexer do
    it 'accepts multiple selectors within brackets, comma-separated' do
      expect(described_class.lex('$[1, 2]')).to eq([:root, :child_start, 1, :union, 2, :child_end, :eof])
    end

    context 'when tokenizing name selector' do
      it 'tokenizes name selector' do
        expect(described_class.lex('$.name')).to eq([:root, :dot, 'name', :eof])
      end

      it 'tokenizes name selector with numeric characters' do
        expect(described_class.lex('$.abc123')).to eq([:root, :dot, 'abc123', :eof])
      end

      it 'accepts double quotes around name' do
        expect(described_class.lex('$.["a a"]')).to eq([:root, :dot, :child_start, 'a a', :child_end, :eof])
      end

      it 'accepts quotes around name' do
        expect(described_class.lex("$.['a a']")).to eq([:root, :dot, :child_start, 'a a', :child_end, :eof])
      end

      it 'accepts name with @ in quotes' do
        # "@" lexes as type :string not as :current_node
        expect(described_class.lex('$.["@"]')).to eq(%i[root dot child_start string child_end eof])
      end

      it 'accepts name with . in quotes' do
        expect(described_class.lex('$.["a.b"]')).to eq([:root, :dot, :child_start, 'a.b', :child_end, :eof])
      end

      # Escaping rules are defined here:
      # https://www.rfc-editor.org/rfc/rfc9535.html#name-semantics-3
      it 'converts chars \b to backspace' do
        expect(described_class.lex('$.["\b"]')).to eq([:root, :dot, :child_start, "\b", :child_end, :eof])
      end

      it 'converts chars \t to tab' do
        expect(described_class.lex('$.["\t"]')).to eq([:root, :dot, :child_start, "\t", :child_end, :eof])
      end

      it 'converts chars \n to line feed' do
        expect(described_class.lex('$.["\n"]')).to eq([:root, :dot, :child_start, "\n", :child_end, :eof])
      end

      it 'converts chars \f to form feed' do
        expect(described_class.lex('$.["\f"]')).to eq([:root, :dot, :child_start, "\f", :child_end, :eof])
      end

      it 'converts chars \r to carriage return' do
        expect(described_class.lex('$.["\r"]')).to eq([:root, :dot, :child_start, "\r", :child_end, :eof])
      end

      it 'converts chars \" to double quote, inside double quotes' do
        expect(described_class.lex('$.["\""]')).to eq([:root, :dot, :child_start, '"', :child_end, :eof])
      end

      it "converts chars \\' to apostrophe, inside single quotes" do
        expect(described_class.lex("$.['\\'']")).to eq([:root, :dot, :child_start, "'", :child_end, :eof])
      end

      it 'converts chars \\ to backslash' do
        expect(described_class.lex('$.["\\\\"]')).to eq([:root, :dot, :child_start, '\\', :child_end, :eof])
      end

      it 'converts hexadecimal escape in uppercase to unicode' do
        expect(described_class.lex('$.["\u263A"]')).to eq([:root, :dot, :child_start, '☺', :child_end, :eof])
      end

      it 'converts hexadecimal escape in lowercase to unicode' do
        expect(described_class.lex('$.["\u263a"]')).to eq([:root, :dot, :child_start, '☺', :child_end, :eof])
      end

      # rubocop: disable RSpec/MultipleExpectations
      it 'converts UTF-16 surrogate pair to UTF-8' do
        token = described_class.lex('$["\\uD83D\\uDE09"]').find { |tk| tk.type == :string }
        expect(token.literal.encoding).to be(Encoding::UTF_8)
        expect(token.literal).to eq('😉')
      end
      # rubocop: enable RSpec/MultipleExpectations

      it 'accepts unicode escape that starts with D but is still non-surrogate' do
        tokens = described_class.lex('$["\\uD7FF"]')
        expect(tokens[2]).to have_attributes(
          type: :string,
          literal: "\uD7FF"
        )
      end

      it 'tokenizes name starting with extended unicode' do
        expect(described_class.lex('$.☺☺abc').map(&:type)).to eq(%I[root dot identifier eof])
      end

      it 'allows newline after ?' do
        expected = [:root, :child_start, :filter, :dot, 'one', :equal, :number, :child_end, :eof]
        expect(described_class.lex("$[?\n.one == 1]")).to eq(expected)
      end
    end

    context 'when tokenizing index selector' do
      it 'tokenizes index selector' do
        expect(described_class.lex('$[0]')).to eq([:root, :child_start, 0, :child_end, :eof])
      end

      it 'handles multi digit indices' do
        expect(described_class.lex('$[987]')).to eq([:root, :child_start, 987, :child_end, :eof])
      end

      it 'handles negative indices' do
        expect(described_class.lex('$[-123]')).to eq([:root, :child_start, :minus, 123, :child_end, :eof])
      end
    end

    context 'when tokenizing array slice selector' do
      it 'handles start and end' do
        expected = [:root, :child_start, 1, :array_slice_separator, 3, :child_end, :eof]
        expect(described_class.lex('$[1:3]')).to eq(expected)
      end

      it 'handles start only' do
        expect(described_class.lex('$[5:]'))
          .to eq([:root, :child_start, 5, :array_slice_separator, :child_end, :eof])
      end

      it 'handles start, end and step' do
        expect(described_class.lex('$[1:5:2]'))
          .to eq([:root, :child_start, 1, :array_slice_separator, 5, :array_slice_separator, 2, :child_end, :eof])
      end

      it 'handles start, end and negative step' do
        expected = [
          :root, :child_start, 5, :array_slice_separator, 1, :array_slice_separator, :minus, 2, :child_end, :eof,
        ]
        expect(described_class.lex('$[5:1:-2]')).to eq(expected)
      end

      it 'handles negative step with nothing else' do
        expect(described_class.lex('$[::-1]'))
          .to eq([:root, :child_start, :array_slice_separator, :array_slice_separator, :minus, 1, :child_end, :eof])
      end
    end

    context 'when tokenizing filter selector' do
      it 'tokenizes equality operator, with parentheses' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :equal, :dot, 'two', :group_end,
                    :child_end, :eof,]
        expect(described_class.lex('$[?(.one == .two)]')).to eq(expected)
      end

      it 'tokenizes equality operator, without parentheses' do
        expected = [:root, :child_start, :filter, :dot, 'one', :equal, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one == .two ]')).to eq(expected)
      end

      it 'tokenizes non-equality operator, with parentheses' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :not_equal, :dot, 'two', :group_end,
                    :child_end, :eof,]
        expect(described_class.lex('$[?(.one != .two)]')).to eq(expected)
      end

      it 'tokenizes non-equality operator, without parentheses' do
        expected = [:root, :child_start, :filter, :dot, 'one', :not_equal, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one != .two ]')).to eq(expected)
      end

      it 'tokenizes less-than operator, with parentheses' do
        expected = [
          :root, :child_start, :filter, :group_start, :dot, 'one',
          :less_than, :dot, 'two', :group_end, :child_end, :eof,
        ]
        expect(described_class.lex('$[?(.one < .two)]')).to eq(expected)
      end

      it 'tokenizes less-than operator, without parentheses' do
        expected = [:root, :child_start, :filter, :dot, 'one', :less_than, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one < .two]')).to eq(expected)
      end

      it 'tokenizes less-than-or-equal operator, with parentheses' do
        expected = [
          :root, :child_start, :filter, :group_start, :dot, 'one', :less_than_or_equal,
          :dot, 'two', :group_end, :child_end, :eof,
        ]
        expect(described_class.lex('$[?(.one <= .two)]')).to eq(expected)
      end

      it 'tokenizes less-than-or-equal operator, without parentheses' do
        expected = [:root, :child_start, :filter, :dot, 'one', :less_than_or_equal, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one <= .two ]')).to eq(expected)
      end

      it 'tokenizes greater-than operator, with parentheses' do
        expected = [
          :root, :child_start, :filter, :group_start, :dot, 'one', :greater_than,
          :dot, 'two', :group_end, :child_end, :eof,
        ]
        expect(described_class.lex('$[?(.one > .two)]')).to eq(expected)
      end

      it 'tokenizes greater-than operator, without parentheses' do
        expected = [
          :root, :child_start, :filter, :dot, 'one', :greater_than,
          :dot, 'two', :child_end, :eof,
        ]
        expect(described_class.lex('$[?.one > .two]')).to eq(expected)
      end

      it 'tokenizes greater-than-or-equal operator, with parentheses' do
        expected = [
          :root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal,
          :dot, 'two', :group_end, :child_end, :eof,
        ]
        expect(described_class.lex('$[?(.one >= .two)]')).to eq(expected)
      end

      it 'tokenizes greater-than-or-equal operator, without parentheses' do
        expected = [
          :root, :child_start, :filter, :dot, 'one', :greater_than_or_equal,
          :dot, 'two', :child_end, :eof,
        ]
        expect(described_class.lex('$[?.one>=.two]')).to eq(expected)
      end

      it 'tokenizes not operator, with parentheses' do
        expected = [:root, :child_start, :filter, :group_start, :not, 'property', :group_end, :child_end, :eof]
        expect(described_class.lex('$[?(!property)]')).to eq(expected)
      end

      it 'tokenizes not operator, without parentheses' do
        expected = [:root, :child_start, :filter, :not, 'property', :child_end, :eof]
        expect(described_class.lex('$[?!property]')).to eq(expected)
      end

      it 'tokenizes and operator, with parentheses' do
        expected = %I[root child_start filter group_start true and false group_end child_end eof]
        expect(described_class.lex('$[?(true && false)]')).to eq(expected)
      end

      it 'tokenizes and operator, without parentheses' do
        expected = %I[root child_start filter true and false child_end eof]
        expect(described_class.lex('$[? true && false]')).to eq(expected)
      end

      it 'tokenizes or operator, with parentheses' do
        expected = %I[root child_start filter group_start true or false group_end child_end eof]
        expect(described_class.lex('$[?(true || false)]')).to eq(expected)
      end

      it 'tokenizes or operator, without parentheses' do
        expected = %I[root child_start filter true or false child_end eof]
        expect(described_class.lex('$[? true || false]')).to eq(expected)
      end

      it 'tokenizes true' do
        expected = %I[root child_start filter true child_end eof]
        expect(described_class.lex('$[? true]')).to eq(expected)
      end

      it 'tokenizes false' do
        expected = %I[root child_start filter false child_end eof]
        expect(described_class.lex('$[? false]')).to eq(expected)
      end

      it 'tokenizes null' do
        expected = %I[root child_start filter null child_end eof]
        expect(described_class.lex('$[? null]')).to eq(expected)
      end

      # null is officially allowed to be a name by the IETF standard:
      # https://www.rfc-editor.org/rfc/rfc9535.html#section-2.6.1-3
      it 'accepts null as a name in a name selector' do
        expected = %I[root dot identifier eof]
        expect(described_class.lex('$.null')).to eq(expected)
      end

      # Since null is allowed to be a name, presumably true/false are allowed too
      it 'accepts true as a name in a name selector' do
        expected = %I[root dot identifier eof]
        expect(described_class.lex('$.true')).to eq(expected)
      end

      it 'accepts false as a name in a name selector' do
        expected = %I[root dot identifier eof]
        expect(described_class.lex('$.false')).to eq(expected)
      end

      it 'tokenizes wildcard' do
        expected = %I[root child_start wildcard child_end eof]
        expect(described_class.lex('$[*]')).to eq(expected)
      end

      it 'tokenizes current_node operator' do
        # only valid within filter selector
        expected = %I[
          root child_start filter group_start current_node dot identifier less_than
          number group_end child_end eof
        ]
        expect(described_class.lex('$[?(@.price < 10)]')).to eq(expected)
      end

      it 'handles comparison of name selectors that both use root nodes' do
        query = '$.absent1 == $.absent2'
        expected = %I[root dot identifier equal root dot identifier eof]
        expect(described_class.lex(query)).to eq(expected)
      end

      it 'tokenizes number' do
        expected = %I[root child_start filter current_node greater_than number child_end eof]
        expect(described_class.lex('$[?@>3]')).to eq(expected)
      end

      it 'tokenizes number with decimal point' do
        expected = %I[root child_start filter current_node greater_than number child_end eof]
        expect(described_class.lex('$[?@>3.5]')).to eq(expected)
      end

      it 'raises error when number has leading zeros' do
        expect {
          described_class.lex('$[?@.a==00]')
        }.to raise_error(Error, /Number may not start with leading zero: "00"/)
      end

      it 'recognizes function "length"' do
        expected = %I[
          root child_start filter function group_start current_node dot
          identifier group_end greater_than_or_equal number child_end eof
        ]
        expect(described_class.lex('$[?length(@.authors) >= 5]')).to eq(expected)
      end

      it 'recognizes function "count"' do
        expected = %I[
          root child_start filter function group_start current_node dot
          wildcard dot identifier group_end greater_than_or_equal number child_end eof
        ]
        expect(described_class.lex('$[?count(@.*.author) >= 5]')).to eq(expected)
      end

      it 'recognizes function "match"' do
        expected = %I[
          root dot identifier child_start filter function group_start current_node dot
          identifier union string group_end child_end eof
        ]
        expect(described_class.lex('$.a[?match(@.b, "[str]")]')).to eq(expected)
      end

      it 'recognizes function "search"' do
        expected = %I[
          root child_start filter function group_start current_node dot
          identifier union string group_end child_end eof
        ]
        expect(described_class.lex('$[?search(@.author, "[BR]ob")]')).to eq(expected)
      end

      it 'recognizes function "value"' do
        expected = %I[
          root child_start filter function group_start current_node descendants
          identifier group_end equal string child_end eof
        ]
        expect(described_class.lex('$[?value(@..color) == "red"]')).to eq(expected)
      end

      it 'tokenizes exponent' do
        token = described_class.lex('$[?(@.price < 5e3)]').find { |tk| tk.type == :number }
        expect(token.literal).to eq(5000)
      end

      it 'tokenizes exponent with explicit +' do
        tokens = described_class.lex('$[?(@.price < 5e+2)]')
        token = tokens.find { |tk| tk.type == :number }
        expect(token).to have_attributes(
          lexeme: '5e+2',
          literal: 500.0
        )
      end

      it 'tokenizes negative exponent' do
        tokens = described_class.lex('$[?(@.price < 5e-2)]')
        token = tokens.find { |tk| tk.type == :number }
        expect(token).to have_attributes(
          lexeme: '5e-2',
          literal: 0.05
        )
      end

      it 'tokenizes exponent with capital E' do
        token = described_class.lex('$[?(@.price < 5E2)]').find { |tk| tk.type == :number }
        expect(token.literal).to eq(500)
      end

      it 'raises error when exponent lacks trailing number' do
        expect {
          described_class.lex('$[?@.a == 1e]')
        }.to raise_error(Error, /Exponent 'e' must be followed by number/)
      end

      it 'tokenizes true in a function call as true type, not a string' do
        expected = %I[
          root child_start filter function group_start true group_end greater_than
          number child_end eof
        ]
        expect(described_class.lex('$[?length(true) > 5]')).to eq(expected)
      end

      it 'tokenizes null in a function call as null type, not a string' do
        expected = %I[
          root child_start filter function group_start null group_end greater_than
          number child_end eof
        ]
        expect(described_class.lex('$[?length(null) > 5]')).to eq(expected)
      end

      # CTS "name selector, double quotes, escaped solidus",
      it 'tokenizes escaped slash character in a double quoted string' do
        tokens = described_class.lex('$["\\/"]')
        expect(tokens[2]).to have_attributes(
          type: :string,
          lexeme: '"\\/"', # lexeme retains unnecessary escape
          literal: '/' # literal discards unnecessary escape
        )
      end

      it 'tokenizes escaped double quote in a double quoted string' do
        tokens = described_class.lex('$["\\""]')
        expect(tokens[2]).to have_attributes(
          type: :string,
          lexeme: '"\""',
          literal: '"'
        )
      end

      it 'raises error when given a char that is not allowed' do
        expect {
          described_class.lex("$[\"\0\"]")
        }.to raise_error(Error, /invalid character "\\u0000"/)
      end

      it 'raises error when given an escaped char that is not allowed' do
        expect {
          described_class.lex("$[\"\\\0\"]")
        }.to raise_error(Error, /Invalid character "\\u0000"/)
      end

      it 'raises error when there is space between minus operator and number' do
        expect {
          described_class.lex('$[?@.a==- 1]')
        }.to raise_error(Error, /Operator "-" must not be followed by whitespace/)
      end

      # CTS "name selector, double quotes, invalid escaped single quote"
      it 'raises error when name contains invalid escaped single quote' do
        expect {
          described_class.lex("$[\"\\'\"]")
        }.to raise_error(Error, /Character ' must not be escaped within double quotes/)
      end

      # CTS "name selector, single quotes, invalid escaped double quote",
      it 'raises error when name contains invalid escaped double quote' do
        expect {
          described_class.lex("$['\\\"']")
        }.to raise_error(Error, /Character " must not be escaped within single quotes/)
      end

      # CTS "name selector, double quotes, question mark escape"
      it 'raises error when name contains an unnecessarily escaped character' do
        expect {
          described_class.lex('$["\\?"]')
        }.to raise_error(Error, /Character \? must not be escaped/)
      end

      # CTS "basic, no leading whitespace",
      it 'raises error when query starts with whitesapce' do
        expect {
          described_class.lex(' $')
        }.to raise_error(Error, /JSONPath query may not start or end with whitespace/)
      end

      # CTS "basic, no trailing whitespace",
      it 'raises error when query ends with whitesapce' do
        expect {
          described_class.lex('$ ')
        }.to raise_error(Error, /JSONPath query may not start or end with whitespace/)
      end

      it 'raises error when descendant segment is followed by space' do
        expect {
          described_class.lex('$.. a')
        }.to raise_error(Error, /Operator "\.\." must not be followed by whitespace/)
      end

      # "name selector, double quotes, unicode escape no hex"
      it 'raises error when string contains unicode escape prefix \u without hex code' do
        expect {
          described_class.lex('$["\u"]')
        }.to raise_error(Error, /Invalid unicode escape sequence: \\u"/)
      end

      # CTS name selector, double quotes, single low surrogate"
      it 'raises error when low surrogate is not preceded by high surrogate' do
        expect {
          described_class.lex('$["\\uDC00"]')
        }.to raise_error(Error, /Invalid unicode escape sequence: \\uDC00/)
      end
    end
  end
end
