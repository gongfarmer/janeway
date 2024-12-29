# frozen_string_literal: true

require 'jsonpath2/lexer'

module JsonPath2
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
      # https://ietf-wg-jsonpath.github.io/draft-ietf-jsonpath-base/draft-ietf-jsonpath-base.html#name-semantics-3
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

      it "converts chars ' to apostrophe, inside single quotes" do
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

    it 'tokenizes array slice selector' do
      expect(described_class.lex('$[1:3]')).to eq([:root, :child_start, 1, :array_slice_separator, 3, :child_end, :eof])
      expect(described_class.lex('$[5:]')).to eq([:root, :child_start, 5, :array_slice_separator, :child_end, :eof])
      expect(described_class.lex('$[1:5:2]')).to eq([:root, :child_start, 1, :array_slice_separator, 5, :array_slice_separator,
                                                     2, :child_end, :eof])
      expect(described_class.lex('$[5:1:-2]')).to eq([:root, :child_start, 5, :array_slice_separator, 1, :array_slice_separator,
                                                      :minus, 2, :child_end, :eof])
      expect(described_class.lex('$[::-1]')).to eq([:root, :child_start, :array_slice_separator, :array_slice_separator, :minus,
                                                    1, :child_end, :eof])
    end

    context 'when tokenizing filter selector' do
      it 'tokenizes equality operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :equal, :dot, 'two', :group_end,
                    :child_end, :eof]
        expect(described_class.lex('$[?(.one == .two)]')).to eq(expected)
      end

      it 'tokenizes equality operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :equal, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one == .two ]')).to eq(expected)
      end

      it 'tokenizes non-equality operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :not_equal, :dot, 'two', :group_end,
                    :child_end, :eof]
        expect(described_class.lex('$[?(.one != .two)]')).to eq(expected)
      end

      it 'tokenizes non-equality operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :not_equal, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one != .two ]')).to eq(expected)
      end

      it 'tokenizes less-than operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :less_than, :dot, 'two', :group_end,
                    :child_end, :eof]
        expect(described_class.lex('$[?(.one < .two)]')).to eq(expected)
      end

      it 'tokenizes less-than operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :less_than, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one < .two]')).to eq(expected)
      end

      it 'tokenizes less-than-or-equal operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :less_than_or_equal, :dot, 'two',
                    :group_end, :child_end, :eof]
        expect(described_class.lex('$[?(.one <= .two)]')).to eq(expected)
      end

      it 'tokenizes less-than-or-equal operator, without brackets' do
        expected = [:root, :child_start, :filter, :dot, 'one', :less_than_or_equal, :dot, 'two', :child_end, :eof]
        expect(described_class.lex('$[? .one <= .two ]')).to eq(expected)
      end

      it 'tokenizes greater-than operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than, :dot, 'two', :group_end,
                    :child_end, :eof]
        expect(described_class.lex('$[?(.one > .two)]')).to eq(expected)
      end

      it 'tokenizes greater-than operator, without brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than, :dot, 'two', :group_end,
                    :child_end, :eof]
        expect(described_class.lex('$[?(.one > .two)]')).to eq(expected)
      end

      it 'tokenizes greater-than-or-equal operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal, :dot, 'two',
                    :group_end, :child_end, :eof]
        expect(described_class.lex('$[?(.one >= .two)]')).to eq(expected)
      end

      it 'tokenizes greater-than-or-equal operator, without brackets' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal, :dot, 'two',
                    :group_end, :child_end, :eof]
        expect(described_class.lex('$[?(.one >= .two)]')).to eq(expected)
      end

      it 'tokenizes not operator, with brackets' do
        expected = [:root, :child_start, :filter, :group_start, :not, 'property', :group_end, :child_end, :eof]
        expect(described_class.lex('$[?(!property)]')).to eq(expected)
      end

      it 'tokenizes not operator, without brackets' do
        expected = [:root, :child_start, :filter, :not, 'property', :child_end, :eof]
        expect(described_class.lex('$[?!property]')).to eq(expected)
      end

      it 'tokenizes and operator, with brackets' do
        expected = %I[root child_start filter group_start true and false group_end child_end eof]
        expect(described_class.lex('$[?(true && false)]')).to eq(expected)
      end

      it 'tokenizes and operator, without brackets' do
        expected = %I[root child_start filter true and false child_end eof]
        expect(described_class.lex('$[? true && false]')).to eq(expected)
      end

      it 'tokenizes or operator, with brackets' do
        expected = %I[root child_start filter group_start true or false group_end child_end eof]
        expect(described_class.lex('$[?(true || false)]')).to eq(expected)
      end

      it 'tokenizes or operator, without brackets' do
        expected = %I[root child_start filter true or false child_end eof]
        expect(described_class.lex('$[? true || false]')).to eq(expected)
      end

      it 'tokenizes grouping function expressions' do
        expected = [:root, :child_start, :filter, :group_start, :dot, 'one', :greater_than_or_equal, :dot, 'two',
                    :group_end, :child_end, :eof]
        expect(described_class.lex('$[?(.one >= .two)]')).to eq(expected)
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

      it 'tokenizes wildcard' do
        expected = %I[root child_start wildcard child_end eof]
        expect(described_class.lex('$[*]')).to eq(expected)
      end

      it 'tokenizes current_node operator' do
        # only valid within filter selector
        expected = %I[root child_start filter group_start current_node dot identifier less_than number group_end
                      child_end eof]
        expect(described_class.lex('$[?(@.price < 10)]')).to eq(expected)
      end

      it 'handles comparison of name selectors that both use root nodes' do
        query = '$.absent1 == $.absent2'
        expected = %I[root dot identifier equal root dot identifier eof]
        expect(described_class.lex(query)).to eq(expected)
      end
    end
  end
end
