# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Enumerator do
    # The #each method gets most of the testing because it is directly implemented in Janeway
    # and has a lot of supporting methods.
    #
    # The remaining methods have minimal tests because they are provided by the Enumerable
    # module, and make use of #each internally.
    #
    # The #delete method is also implemented in Janeway, but it is tested in detail
    # in the files spec/lib/janeway/interpreter/*_deleter_spec.rb
    #
    describe '.each' do
      it 'yields one input value from a singular query' do
        input = { 'a' => { 'b' => { 'c' => 5 } } }
        seen = Janeway.enum_for('$.a.b.c', input).map do |value|
          value
        end
        expect(seen).to eq([5])
      end

      it 'yields all values from a non-singular query' do
        input = { 'a' => %w[a b c], 'b' => %w[d e f] }
        seen = Janeway.enum_for('$.*', input).map do |value|
          value
        end
        expect(seen).to eq([%w[a b c], %w[d e f]])
      end

      it 'can modify the queried value' do
        input = { 'a' => %w[a b c], 'b' => %w[d e f] }
        Janeway.enum_for('$.*', input).each do |arr|
          arr.delete_at(1)
        end
        expected = { 'a' => %w[a c], 'b' => %w[d f] }
        expect(input).to eq(expected)
      end

      it 'returns an enumerator if no block given' do
        expect(Janeway.enum_for('$', {}).each).to be_a(::Enumerator) # this one is not a Janewway::Enumerator
      end

      it 'returns an enumerator that enumerates on matched values' do
        input = { 'a' => %w[a b c], 'b' => %w[d e f] }
        expected = [%w[a b c], %w[d e f]]
        enum = Janeway.enum_for('$.*', input)
        expect(enum.to_a).to eq(expected)
      end

      it 'raises error when no query given' do
        expect {
          Janeway.enum_for(nil, {}).each { puts }
        }.to raise_error(ArgumentError, /expect jsonpath string, got nil/)
      end

      context 'when iterating with a name selector' do
        let(:input) { { 'a' => { 'b' => { 'c' => 1 } } } }

        it "yields the value and also the hash that contains the value's key" do
          Janeway.enum_for('$.a.b.c', input).each do |value, parent|
            expect(value).to eq(1)
            expect(parent).to eq({ 'c' => 1 })
          end
        end

        it 'yields the normalized path' do
          {
            '$.a' => "$['a']",
            '$.a.b' => "$['a']['b']",
            '$.a.b.c' => "$['a']['b']['c']",
          }.each do |jsonpath, normalized_path|
            Janeway.enum_for(jsonpath, input).each do |_, _, _, path|
              expect(path).to eq(normalized_path)
            end
          end
        end

        context 'over a hash with keys that need special quoting' do
          let(:input) do
            JSON.parse(<<~JSON_STRING)
              {
                "o": {"j j": {"k.k": 3}},
                "'": {"@": 2}
              }
            JSON_STRING
          end

          it 'yields normalized path for hash keys that need single quotes' do
            Janeway.enum_for('$.o["j j"]', input).each do |_, _, _, path|
              expect(path).to eq("$['o']['j j']")
            end
          end

          it 'yields normalized path for hash keys that need double quotes' do
            Janeway.enum_for('$["\'"]', input).each do |_, _, _, path|
              expect(path).to eq("$['\\'']")
            end
          end
        end
      end

      context 'when iterating with a wildcard selector' do
        context 'over an array' do
          let(:input) { %w[a b c] }

          it 'yields value, array that contains value, and array index' do
            Janeway.enum_for('$.*', input).each do |value, parent, index|
              expect(input).to include(value)
              expect(parent).to eq(input)
              expect(parent[index]).to eq(value)
            end
          end

          it 'yields the normalized path' do
            results = Janeway.enum_for('$.*', input).map do |_, _, _, path|
              path
            end
            expect(results).to eq(%w[$[0] $[1] $[2]])
          end
        end

        context 'over a hash' do
          let(:input) { { 'a' => { 'b' => { 'c' => 1 } } } }

          it 'yields value, hash that contains value, and hash key' do
            Janeway.enum_for('$.*', input).each do |value, parent, key|
              expect(value).to eq({ 'b' => { 'c' => 1 } })
              expect(parent).to eq(input)
              expect(parent[key]).to eq(value)
            end
          end

          it 'yields the normalized path' do
            {
              '$.*' => "$['a']",
              '$.*.*' => "$['a']['b']",
              '$.*.*.*' => "$['a']['b']['c']",
            }.each do |jsonpath, normalized_path|
              Janeway.enum_for(jsonpath, input).each do |_, _, _, path|
                expect(path).to eq(normalized_path)
              end
            end
          end
        end
      end

      context 'when iterating with an index selector' do
        let(:input) { %w[a b c] }

        it 'yields the value and also the array that contains the value' do
          Janeway.enum_for('$[2]', input).each do |value, parent|
            expect(value).to eq('c')
            expect(parent).to eq(input)
          end
        end

        it 'yields the normalized path' do
          [
            '$[0]',
            '$[1]',
            '$[2]',
          ].each do |jsonpath|
            Janeway.enum_for(jsonpath, input).each do |_, _, _, path|
              expect(path).to eq(jsonpath)
            end
          end
        end
      end

      context 'when iterating with an array slice selector' do
        let(:input) { %w[a b c d e f g h] }

        it 'yields the value and also the array that contains the value' do
          seen = []
          Janeway.enum_for('$[1:7:2]', input).each do |value, parent|
            seen << value
            expect(parent).to eq(input)
          end
          expect(seen).to eq(%w[b d f])
        end

        it 'yields the normalized path' do
          paths = Janeway.enum_for('$[1:7:2]', input).map do |_, _, _, path|
            path
          end
          expect(paths).to eq(%w[$[1] $[3] $[5]])
        end
      end

      context 'when iterating with a filter selector' do
        let(:input) do
          [
            { 'name' => 'bucket', 'cost' => 9.99 },
            { 'name' => 'shovel', 'cost' => 18 },
            { 'name' => 'hose', 'cost' => 20.50 },
            { 'name' => 'trowel', 'cost' => 7.44 },
          ]
        end

        it 'yields the value and also the array that contains the value' do
          Janeway.enum_for('$[? @.cost < 15]', input).each do |value, parent, key|
            expect(%w[bucket trowel]).to include(value['name'])
            expect(parent).to eq(input)
            expect(parent[key]).to eq(value)
          end
        end

        it 'yields the normalized path' do
          paths = Janeway.enum_for('$[? @.cost < 15]', input).map do |_, _, _, path|
            path
          end
          expect(paths).to eq(%w[$[0] $[3]])
        end

        it 'yields the normalized path when there is a following name selector' do
          paths = Janeway.enum_for('$[? @.cost < 15].name', input).map do |_, _, _, path|
            path
          end
          expect(paths).to eq(%w[$[0]['name'] $[3]['name']])
        end
      end

      context 'when iterating with a descendant segment' do
        let(:input) { [{ 'name' => 'bucket', 'cost' => 9.99 }] }

        it 'yields the value and also the array that contains the value' do
          expected = [
            [{ 'name' => 'bucket', 'cost' => 9.99 }, input],
            ['bucket', { 'name' => 'bucket', 'cost' => 9.99 }],
            [9.99, { 'name' => 'bucket', 'cost' => 9.99 }],
          ]
          Janeway.enum_for('$..*', input).each do |value, parent, index|
            expect(expected).to include([value, parent])
            expect(value).to eq(parent[index])
          end
        end

        it 'yields the normalized path' do
          paths = Janeway.enum_for('$..*', input).map do |_, _, _, path|
            path
          end
          expected = ['$[0]', "$[0]['name']", "$[0]['cost']"]
          expect(paths).to eq(expected)
        end
      end

      context 'when iterating through a child segment containing multiple selectors' do
        let(:input) do
          [
            { 'name' => 'bucket', 'cost' => 9.99 },
            { 'name' => 'shovel', 'cost' => 18 },
            { 'name' => 'hose', 'cost' => 20.50 },
            { 'name' => 'trowel', 'cost' => 7.44 },
          ]
        end

        it 'iterates to the end of all selectors in the child segment' do
          seen = []
          Janeway.enum_for("$.*['name', 'cost']", input).each do |value, parent, key|
            seen << value
            expect(value).to eq(parent[key])
          end
          expect(seen).to eq(['bucket', 9.99, 'shovel', 18, 'hose', 20.5, 'trowel', 7.44])
        end

        it 'builds normalized path for every result' do
          paths = Janeway.enum_for("$.*['name', 'cost']", input).map do |_value, _parent, _key, path|
            path
          end
          expected =
            [
              "$[0]['name']",
              "$[0]['cost']",
              "$[1]['name']",
              "$[1]['cost']",
              "$[2]['name']",
              "$[2]['cost']",
              "$[3]['name']",
              "$[3]['cost']",
            ]
          expect(paths).to eq(expected)
        end

        it 'collects values from all branches when query contains multiple child segments' do
          input =
            {
              'cars' =>
                {
                  'honda' => [
                    { 'name' => 'civic', 'type' => 'sedan' },
                    { 'name' => 'cr-v', 'type' => 'suv' },
                    { 'name' => 'pilot', 'type' => 'suv' },
                    { 'name' => 'accord', 'type' => 'sedan' },
                  ],
                  'toyota' => [
                    { 'name' => 'corolla', 'type' => 'sedan' },
                    { 'name' => 'rav-4', 'type' => 'suv' },
                    { 'name' => 'land cruiser', 'type' => 'truck' },
                    { 'name' => '4runner', 'type' => 'truck' },
                  ],
                },
            }
          values = Janeway.enum_for("$.cars['honda', 'toyota'].*['name', 'type']", input).search
          expected = [
            'civic', 'sedan', 'cr-v', 'suv', 'pilot', 'suv', 'accord', 'sedan',
            'corolla', 'sedan', 'rav-4', 'suv', 'land cruiser', 'truck', '4runner', 'truck',
          ]
          expect(values).to eq(expected)
        end
      end
    end

    describe '#map' do
      it 'transforms matched values' do
        input = [1, 2, 3]
        results = Janeway.enum_for('$.*', input).map { |v| v * 2 }
        expect(results).to eq([2, 4, 6])
      end
    end

    describe '#each_with_index' do
      context 'when input is a Array' do
        it 'returns values with index' do
          input = [1, 2, 3]
          results = Janeway.enum_for('$.*', input).each_with_index.to_a
          expect(results).to eq([[1, 0], [2, 1], [3, 2]])
        end
      end

      context 'when input is a Hash' do
        it 'returns values with index' do
          input = { 'a' => 1, 'b' => 2, 'c' => 3 }
          results = Janeway.enum_for('$.*', input).each_with_index.to_a
          expect(results).to eq([[1, 0], [2, 1], [3, 2]])
        end
      end
    end

    describe '#each_with_object' do
      it 'returns values with index' do
        input = [1, 2, 3]
        result = []
        Janeway.enum_for('$.*', input).each_with_object(result) do |value, arr|
          arr << value
        end
        expect(result).to eq(input)
      end
    end

    describe '#next' do
      it 'returns values with index' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input).map
        expect(enum.next).to eq(1)
        expect(enum.next).to eq(2)
        expect(enum.next).to eq(3)
        expect { enum.next }.to raise_error(StopIteration)
      end
    end

    describe '#select' do
      it 'collects returned values that matched the condition' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input)
        result = enum.select(&:odd?)
        expect(result).to eq([1, 3])
      end
    end

    describe '#reject' do
      it 'collects returned values that matched the condition' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input)
        result = enum.reject(&:odd?)
        expect(result).to eq([2])
      end
    end

    describe '#filter_map' do
      it 'collects and modifies values return by the query' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input)
        result = enum.filter_map { |value| value**2 if value.odd? }
        expect(result).to eq([1, 9])
      end
    end
  end
end
