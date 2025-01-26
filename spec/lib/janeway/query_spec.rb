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

    describe '#each' do
      it 'yields values from the input' do
        input = { 'a' => %w[a b c], 'b' => %w[d e f] }
        seen = []
        query = Parser.parse('$.*.*')
        query.each(input) do |value|
          seen << value
        end
        expect(seen).to eq(%w[a b c d e f])
      end

      it 'yields value, parent, array index and path' do
        input = { 'a' => %w[a b c], 'b' => %w[d e f] }
        query = Parser.parse('$.*.*')
        query.each(input) do |value, parent, index, path|
          expect(parent[index]).to eq(value)
          expect(path).to match(/^\$\['.'\]\[#{index}\]$/)
        end
      end

      it 'returns an enumerator if no block given' do
        query = Parser.parse('$.*.*')
        expect(query.each({})).to be_an(Enumerator)
      end
    end
  end
end
