# frozen_string_literal: true

require 'jsonpath2/lexer'

module JsonPath2
  describe Lexer do
    it 'accepts multiple selectors within brackets, comma-separated' do
      expect(Lexer.lex('$[1, 2]')).to eq([:root, :child_start, 1, :union, 2, :child_end, :eof])
    end
    context 'when tokenizing name selector' do
      it 'tokenizes name selector' do
        expect(Lexer.lex('$.name')).to eq([:root, :dot, 'name', :eof])
      end
      it 'accepts double quotes around name' do
        expect(Lexer.lex('$.["a a"]')).to eq([:root, :dot, :child_start, 'a a', :child_end, :eof])
      end
      it 'accepts quotes around name' do
        expect(Lexer.lex("$.['a a']")).to eq([:root, :dot, :child_start, 'a a', :child_end, :eof])
      end
      it 'accepts name with @ in quotes' do
        # "@" lexes as type :string not as :current_node
        expect(Lexer.lex('$.["@"]')).to eq([:root, :dot, :child_start, :string, :child_end, :eof])
      end
      it 'accepts name with . in quotes' do
        expect(Lexer.lex('$.["a.b"]')).to eq([:root, :dot, :child_start, 'a.b', :child_end, :eof])
      end
      # Escaping rules are defined here:
      # https://ietf-wg-jsonpath.github.io/draft-ietf-jsonpath-base/draft-ietf-jsonpath-base.html#name-semantics-3
      it 'converts chars \b to backspace' do
        expect(Lexer.lex('$.["\b"]')).to eq([:root, :dot, :child_start, "\b", :child_end, :eof])
      end
      it 'converts chars \t to tab' do
        expect(Lexer.lex('$.["\t"]')).to eq([:root, :dot, :child_start, "\t", :child_end, :eof])
      end
      it 'converts chars \n to line feed' do
        expect(Lexer.lex('$.["\n"]')).to eq([:root, :dot, :child_start, "\n", :child_end, :eof])
      end
      it 'converts chars \f to form feed' do
        expect(Lexer.lex('$.["\f"]')).to eq([:root, :dot, :child_start, "\f", :child_end, :eof])
      end
      it 'converts chars \r to carriage return' do
        expect(Lexer.lex('$.["\r"]')).to eq([:root, :dot, :child_start, "\r", :child_end, :eof])
      end
      it 'converts chars \" to double quote, inside double quotes' do
        expect(Lexer.lex('$.["\""]')).to eq([:root, :dot, :child_start, '"', :child_end, :eof])
      end
      it "converts chars \' to apostrophe, inside single quotes" do
        expect(Lexer.lex("$.['\\'']")).to eq([:root, :dot, :child_start, "'", :child_end, :eof])
      end
      it 'converts chars \\ to backslash' do
        expect(Lexer.lex('$.["\\\\"]')).to eq([:root, :dot, :child_start, '\\', :child_end, :eof])
      end
      it 'converts hexadecimal escape in uppercase to unicode' do
        expect(Lexer.lex('$.["\u263A"]')).to eq([:root, :dot, :child_start, '☺', :child_end, :eof])
      end
      it 'converts hexadecimal escape in lowercase to unicode' do
        expect(Lexer.lex('$.["\u263a"]')).to eq([:root, :dot, :child_start, '☺', :child_end, :eof])
      end
    end
    context 'when tokenizing index selector' do
      it 'tokenizes index selector' do
        expect(Lexer.lex('$[0]')).to eq([:root, :child_start, 0, :child_end, :eof])
      end
      it 'handles multi digit indices' do
        expect(Lexer.lex('$[987]')).to eq([:root, :child_start, 987, :child_end, :eof])
      end
      it 'handles negative indices' do
        expect(Lexer.lex('$[-123]')).to eq([:root, :child_start, :minus, 123, :child_end, :eof])
      end
    end
    it 'tokenizes array slice selector' do
      expect(Lexer.lex('$[1:3]')).to eq([:root, :child_start, 1, :array_slice_separator, 3, :child_end, :eof])
      expect(Lexer.lex('$[5:]')).to eq([:root, :child_start, 5, :array_slice_separator, :child_end, :eof])
      expect(Lexer.lex('$[1:5:2]')).to eq([:root, :child_start, 1, :array_slice_separator, 5, :array_slice_separator, 2, :child_end, :eof])
      expect(Lexer.lex('$[5:1:-2]')).to eq([:root, :child_start, 5, :array_slice_separator, 1, :array_slice_separator, :minus, 2, :child_end, :eof])
      expect(Lexer.lex('$[::-1]')).to eq([:root, :child_start, :array_slice_separator, :array_slice_separator, :minus, 1, :child_end, :eof])
    end
    context 'when tokenizing filter selector' do
      it 'tokenizes equality operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :equal, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one == .two)]')).to eq(expected)
      end
      it 'tokenizes equality operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :equal, :dot, 'two', :child_end, :eof]
        expect(Lexer.lex('$[? .one == .two ]')).to eq(expected)
      end
      it 'tokenizes non-equality operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :not_equal, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one != .two)]')).to eq(expected)
      end
      it 'tokenizes non-equality operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :not_equal, :dot, 'two', :child_end, :eof]
        expect(Lexer.lex('$[? .one != .two ]')).to eq(expected)
      end
      it 'tokenizes less-than operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :less_than, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one < .two)]')).to eq(expected)
      end
      it 'tokenizes less-than operator, without brackets' do
        expected = [:root, :child_start, :filter,  :dot, 'one', :less_than, :dot, 'two', :child_end, :eof]
        expect(Lexer.lex('$[? .one < .two]')).to eq(expected)
      end
      it 'tokenizes less-than-or-equal operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :less_than_or_equal, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one <= .two)]')).to eq(expected)
      end
      it 'tokenizes less-than-or-equal operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :less_than_or_equal, :dot, 'two', :child_end, :eof]
        expect(Lexer.lex('$[? .one <= .two ]')).to eq(expected)
      end
      it 'tokenizes greater-than operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one > .two)]')).to eq(expected)
      end
      it 'tokenizes greater-than operator, without brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one > .two)]')).to eq(expected)
      end
      it 'tokenizes greater-than-or-equal operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one >= .two)]')).to eq(expected)
      end
      it 'tokenizes greater-than-or-equal operator, without brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one >= .two)]')).to eq(expected)
      end
      it 'tokenizes not operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :not, 'property', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(!property)]')).to eq(expected)
      end
      it 'tokenizes not operator, without brackets' do
        expected = [:root, :child_start, :filter, :not, 'property', :child_end, :eof]
        expect(Lexer.lex('$[?!property]')).to eq(expected)
      end
      it 'tokenizes and operator, with brackets' do
        expected = %I[root child_start filter group_start true and false group_end child_end eof]
        expect(Lexer.lex('$[?(true && false)]')).to eq(expected)
      end
      it 'tokenizes and operator, without brackets' do
        expected = %I[root child_start filter true and false child_end eof]
        expect(Lexer.lex('$[? true && false]')).to eq(expected)
      end
      it 'tokenizes or operator, with brackets' do
        expected = %I[root child_start filter group_start true or false group_end child_end eof]
        expect(Lexer.lex('$[?(true || false)]')).to eq(expected)
      end
      it 'tokenizes or operator, without brackets' do
        expected = %I[root child_start filter true or false child_end eof]
        expect(Lexer.lex('$[? true || false]')).to eq(expected)
      end
      it 'tokenizes grouping function expressions' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal, :dot, 'two', :group_end, :child_end, :eof]
        expect(Lexer.lex('$[?(.one >= .two)]')).to eq(expected)
      end
      it 'tokenizes true' do
        expected = %I[root child_start filter true child_end eof]
        expect(Lexer.lex('$[? true]')).to eq(expected)
      end
      it 'tokenizes false' do
        expected = %I[root child_start filter false child_end eof]
        expect(Lexer.lex('$[? false]')).to eq(expected)
      end
      it 'tokenizes null' do
        expected = %I[root child_start filter null child_end eof]
        expect(Lexer.lex('$[? null]')).to eq(expected)
      end
      it 'tokenizes wildcard' do
        expected = %I[root child_start wildcard child_end eof]
        expect(Lexer.lex('$[*]')).to eq(expected)
      end
      it 'tokenizes current_node operator' do
        # only valid within filter selector
        expected = %I[root child_start filter group_start current_node dot identifier less_than number group_end child_end eof]
        expect(Lexer.lex('$[?(@.price < 10)]')).to eq(expected)
      end
    end
  end
end
