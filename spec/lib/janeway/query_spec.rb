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
  end
end
