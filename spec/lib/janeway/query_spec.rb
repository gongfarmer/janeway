# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Query do
    describe '#node_list' do
      it 'returns all nodes' do
        query = Parser.parse('$.one[0].*[1:2]')
        nodes = query.node_list.map(&:to_s)
        expect(nodes).to eq(['$.one[0].*[1:2]', '.one[0].*[1:2]', '[0].*[1:2]', '.*[1:2]', '[1:2]'])
      end
    end

    describe '#pop' do
      it 'raises error for non-singular query' do
        query = Parser.parse('$.one[0].*[1:2]')
        expect {
          query.pop
        }.to raise_error(Janeway::Error, /not allowed to pop from a non-singular query/)
      end

      it 'removes the last selector from the query' do
        query = Parser.parse('$.one[0][1]')
        query.pop
        expect(query.to_s).to eq('$.one[0]')
      end

      it 'returns the removed selector' do
        query = Parser.parse('$.one[0][3]')
        selector = query.pop
        expect(selector).to be_a(AST::IndexSelector)
        expect(selector.value).to eq(3)
      end

      it 'raises error when query has just one element' do
        expect {
          Parser.parse('$').pop
        }.to raise_error(Janeway::Error, /cannot pop from single-element query/)
      end
    end

    describe '#singular_query?' do
      it 'returns false for non-singular query' do
        %w[$.* $..a $['a','b'] $.a[?@.b] $.a[1:2]].each do |jsonpath|
          expect(Parser.parse(jsonpath).singular_query?).to be(false)
        end
      end
    end

    describe '#tree' do
      it 'does not raise for a bare root query' do
        expect { Parser.parse('$').tree }.not_to raise_error
      end

      it 'does not raise for a wildcard selector as the terminal segment' do
        expect { Parser.parse('$.a[*]').tree }.not_to raise_error
      end
    end

    describe '#to_s' do
      it 'stringifies a descendant segment followed by a child segment' do
        expect(Parser.parse('$..[1,2]').to_s).to eq('$..[1, 2]')
      end

      it 'preserves the logical-not operator when stringifying' do
        expect(Parser.parse('$[?!@.x]').to_s).to include('!')
      end

      it 'round-trips a logical-not filter through parse -> to_s -> parse' do
        original = Parser.parse('$[?!@.x]')
        expect(Parser.parse(original.to_s).to_s).to eq(original.to_s)
      end
    end
  end
end
