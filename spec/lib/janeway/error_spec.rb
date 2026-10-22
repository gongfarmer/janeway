# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Error do
    let(:query) { '$.a[?@.b ~~ 1]' }

    it 'has only the message when there is no query' do
      expect(described_class.new('oops').message).to eq('oops')
    end

    it 'has no pointer when there is a query but no location' do
      expect(described_class.new('oops', query).message).to eq("Jsonpath query #{query} - oops")
    end

    it 'points at the column when there is a location' do
      message = described_class.new('oops', query, Location.new(9, 1)).message
      expect(message).to eq("Jsonpath query #{query} (col 9) - oops\n#{query}\n#{' ' * 9}^")
    end

    it 'underlines as many characters as the location is long' do
      message = described_class.new('oops', query, Location.new(9, 3)).message
      expect(message.lines.last).to eq("#{' ' * 9}^^^")
    end

    it 'does not point past the end of the query' do
      message = described_class.new('oops', query, Location.new(100, 5)).message
      expect(message.lines.last).to eq("#{' ' * query.length}^")
    end

    it 'keeps the pointer under the column when the query contains a newline' do
      message = described_class.new('oops', "$.a\n[?@.b]", Location.new(5, 1)).message
      expect(message.lines[-2]).to eq("$.a [?@.b]\n")
      expect(message.lines.last).to eq("#{' ' * 5}^")
    end

    it 'points at the column of a lexer error' do
      expect { Janeway.parse(query) }.to raise_error(described_class) { |error|
        expect(error.message.lines.last).to eq("#{' ' * 9}^")
      }
    end

    it 'keeps the query and the location' do
      error = described_class.new('oops', query, Location.new(9, 1))
      expect([error.query, error.location.col]).to eq([query, 9])
    end
  end
end
