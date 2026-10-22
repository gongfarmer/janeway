# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Error do
    let(:query) { '$.a[?@.b ~~ 1]' }
    let(:prefix) { 'Jsonpath query ' }

    it 'has only the message when there is no query' do
      expect(described_class.new('oops').message).to eq('oops')
    end

    it 'has no pointer when there is a query but no location' do
      expect(described_class.new('oops', query).message).to eq("Jsonpath query #{query} - oops")
    end

    # @return [String] the text of the header line that sits under the carets of the last line
    def text_under_carets(message)
      lines = message.lines.map(&:chomp)
      caret_line = lines.last
      start = caret_line.index('^')
      lines.first[start, caret_line.count('^')]
    end

    it 'points at the column when there is a location' do
      message = described_class.new('oops', query, Location.new(9, 1)).message
      expect(message).to eq("Jsonpath query #{query} (col 9) - oops\n#{' ' * (prefix.length + 9)}^")
      expect(message.scan(query).size).to eq(1)
    end

    it 'underlines as many characters as the location is long' do
      message = described_class.new('oops', query, Location.new(9, 3)).message
      expect(message.lines.last).to eq("#{' ' * (prefix.length + 9)}^^^")
    end

    it 'does not point past the end of the query' do
      message = described_class.new('oops', query, Location.new(100, 5)).message
      expect(message.lines.last).to eq("#{' ' * (prefix.length + query.length)}^")
    end

    it 'does not raise for a negative column and points at the start of the query' do
      message = described_class.new('oops', query, Location.new(-5, 1)).message
      expect(message.lines.last).to eq("#{' ' * prefix.length}^")
    end

    it 'does not raise for a nil column and points at the start of the query' do
      message = described_class.new('oops', query, Location.new(nil, 1)).message
      expect(message.lines.last).to eq("#{' ' * prefix.length}^")
    end

    it 'underlines one character when the length is nil' do
      message = described_class.new('oops', query, Location.new(9, nil)).message
      expect(message.lines.last).to eq("#{' ' * (prefix.length + 9)}^")
    end

    it 'underlines one character when the length is zero or negative' do
      [0, -3].each do |length|
        message = described_class.new('oops', query, Location.new(9, length)).message
        expect(message.lines.last).to eq("#{' ' * (prefix.length + 9)}^")
      end
    end

    it 'does not underline past the end of the query' do
      message = described_class.new('oops', query, Location.new(9, 100)).message
      expect(message.lines.last).to eq("#{' ' * (prefix.length + 9)}#{'^' * (query.length - 9)}")
    end

    it 'keeps the carets under the column when the query contains a newline' do
      message = described_class.new('oops', "$.a\n[?@.b]", Location.new(5, 1)).message
      expect(message.lines.first).to eq("Jsonpath query $.a [?@.b] (col 5) - oops\n")
      expect(message.lines.last).to eq("#{' ' * (prefix.length + 5)}^")
    end

    it 'keeps the carets under the column when the query contains a carriage return and newline' do
      message = described_class.new('oops', "$.a\r\n[?@.b]", Location.new(6, 1)).message
      expect(message.lines.first).to eq("Jsonpath query $.a  [?@.b] (col 6) - oops\n")
      expect(message.lines.last).to eq("#{' ' * (prefix.length + 6)}^")
    end

    it 'points at the column of a lexer error' do
      expect { Janeway.parse(query) }.to raise_error(described_class) { |error|
        expect(text_under_carets(error.message)).to eq('~')
      }
    end

    it 'points at the repeat count of an over-limit pattern' do
      expect { Janeway.parse('$[?match(@, "ab{1001}c")]') }.to raise_error(described_class) { |error|
        expect(text_under_carets(error.message)).to eq('1001')
      }
    end

    it 'keeps the query and the location' do
      error = described_class.new('oops', query, Location.new(9, 1))
      expect([error.query, error.location.col]).to eq([query, 9])
    end

    describe 'with a query that is not valid UTF-8' do
      it 'does not raise when there is a location, and still has a caret line' do
        message = nil
        expect { message = described_class.new('m', "$\xff", Location.new(1, 1)).message }.not_to raise_error
        expect(message).to start_with('Jsonpath query $')
        expect(message.lines.last).to match(/\A *\^\z/)
      end

      it 'keeps the raw query in the header when there is no location' do
        message = nil
        expect { message = described_class.new('m', "$\xff").message }.not_to raise_error
        expect(message.b).to eq("Jsonpath query $\xFF - m".b)
      end

      it 'raises Janeway::Error, not ArgumentError, from the parser' do
        expect { Janeway.parse("$['a\xff' ") }.to raise_error(described_class)
      end
    end
  end
end
