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
    describe '#each' do
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
        expect(enum.each.to_a).to eq(expected)
      end

      it 'raises error when no query given' do
        expect {
          Janeway.enum_for(nil, {}).each { $stderr.puts }
        }.to raise_error(ArgumentError, /expect jsonpath string, got nil/)
      end

      context 'when iterating a name selector' do
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

        context 'with a hash whose keys need special quoting' do
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

      context 'when iterating a wildcard selector' do
        context 'with an array' do
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

        context 'with a hash' do
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

    describe '#replace' do
      let(:input) do
        {
          'a' => nil,
          'b' => {
            'a' => 5,
            'b' => { 'a' => 'bird' },
          },
        }
      end

      it 'sets value for a singular query to a top level key' do
        Janeway.enum_for('$.a', input).replace(100)
        expect(input['a']).to eq(100)
        expect(input.dig('b', 'a')).to eq(5)
        expect(input.dig('b', 'b', 'a')).to eq('bird')
      end

      it 'sets value for a singular query to a lower level key' do
        Janeway.enum_for('$.b.b.a', input).replace(100)
        expect(input['a']).to be_nil
        expect(input.dig('b', 'a')).to eq(5)
        expect(input.dig('b', 'b', 'a')).to eq(100)
      end

      it 'sets all values for a descendant segment query that matches multiple keys' do
        Janeway.enum_for('$..a', input).replace(100)
        expect(input['a']).to eq(100)
        expect(input.dig('b', 'a')).to eq(100)
        expect(input.dig('b', 'b', 'a')).to eq(100)
      end

      it 'does not enter infinite loop when the replacement introduces a new match' do
        replacement = { 'a' => nil }
        Janeway.enum_for('$..a', input).replace(replacement)
        expect(input['a']).to eq(replacement)
        expect(input.dig('a', 'a')).to be_nil
        expect(input.dig('b', 'a')).to eq(replacement)
        expect(input.dig('b', 'a', 'a')).to be_nil
        expect(input.dig('b', 'b', 'a')).to eq(replacement)
        expect(input.dig('b', 'b', 'a', 'a')).to be_nil
      end

      it 'accepts nil as a replacement value' do
        Janeway.enum_for('$..a', input).replace(nil)
        expect(input).to eq({ 'a' => nil, 'b' => { 'a' => nil, 'b' => { 'a' => nil } } })
      end

      it 'accepts a block which creates the replacement value' do
        input = %w[1 2 3 4 5]
        Janeway.enum_for('$.*', input).replace(&:to_i)
        expect(input).to eq([1, 2, 3, 4, 5])
      end

      it 'raises if block and replacement value are both given' do
        expect {
          Janeway.enum_for('$.*', input).replace(1) { |value| value + 1 }
        }.to raise_error(Janeway::Error, /#replace needs either replacement value or block, not both/)
      end

      it 'raises if block and nil replacement value are both given' do
        expect {
          Janeway.enum_for('$.*', input).replace(nil) { |value| value + 1 }
        }.to raise_error(Janeway::Error, /#replace needs either replacement value or block, not both/)
      end
    end

    describe '#insert' do
      let(:input) do
        {
          'a' => nil,
          'b' => {
            'a' => 5,
            'b' => { 'a' => 'bird' },
          },
        }
      end

      it 'raises error when query is not a singular query' do
        %w[$.* $..a $['a','b'] $.a[?@.b]].each do |jsonpath|
          expect {
            Janeway.enum_for(jsonpath, input).insert({})
          }.to raise_error(Janeway::Error, /insert may only be used with a singular query/)
        end
      end

      it 'inserts new value into hash that already exists' do
        Janeway.enum_for('$.b.b.new_key', input).insert('new_value')
        expect(input.dig('b', 'b')).to eq({ 'a' => 'bird', 'new_key' => 'new_value' })
      end

      it 'inserts new value into array that already exists when new index is correct' do
        arr = [0, 1, 2, 3]
        Janeway.enum_for('$[4]', arr).insert(4)
        expect(arr).to eq([0, 1, 2, 3, 4])
      end

      it 'rejects array index that is too small' do
        arr = [0, 1, 2, 3]
        expect {
          Janeway.enum_for('$[3]', arr).insert(4)
        }.to raise_error(/array at \$ already has index 3/)
      end

      it 'rejects array index that is too large' do
        arr = [0, 1, 2, 3]
        expect {
          Janeway.enum_for('$[5]', arr).insert(4)
        }.to raise_error(/cannot add index 5 because array at \$ is too small/)
      end

      it 'does not alter the Query object inside the Enumerator' do
        enum = Janeway.enum_for('$.b.b.new_key', input)
        expect(enum.search).to be_empty
        enum.insert({ a: 6 })
        expect(enum.search).to eq([{ a: 6 }])
      end

      it 'raises error when value already exists and no block is given' do
        input = { 'a' => { 'b' => 1 } }
        enum = Janeway.enum_for('$.a', input)
        expect {
          enum.insert({})
        }.to raise_error(Error, /hash at \$ already has key "a"/)
      end

      it 'calls block when hash key already exists and block is given' do
        input = { 'a' => { 'b' => 1 } }
        enum = Janeway.enum_for('$.a', input)
        called = false
        enum.insert({}) do |hash, key|
          called = true
          expect(hash).to eq(input)
          expect(key).to eq('a')
        end
        expect(called).to be(true)
      end

      it 'calls block when array index already exists and block is given' do
        input = { 'a' => [0] }
        enum = Janeway.enum_for('$.a[0]', input)
        called = false
        enum.insert({}) do |array, index|
          called = true
          expect(array).to eq([0])
          expect(index).to eq(0)
        end
        expect(called).to be(true)
      end
    end

    describe '#find_paths' do
      let(:input) { { 'a' => { 'b' => { 'c' => 1 } } } }

      it 'returns normalized paths for query matches' do
        expected = ["$['a']", "$['a']['b']", "$['a']['b']['c']"]
        expect(Janeway.enum_for('$..*', input).find_paths).to eq(expected)
      end

      it 'returns empty list when query does not match anything' do
        expect(Janeway.enum_for('$.a[0]', input).find_paths).to be_empty
      end

      it 'uses positive array index when index selector has negative index' do
        input = %w[a b c]
        expect(Janeway.enum_for('$[-1]', input).find_paths).to eq(['$[2]'])
      end

      it 'uses positive array index when array slice selector has negative range' do
        input = %w[a b c]
        expect(Janeway.enum_for('$[-2:-1]', input).find_paths).to eq(['$[1]'])
      end

      it 'uses positive array index when array slice selector has negative step' do
        input = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        expect(Janeway.enum_for('$[3:1:-1]', input).find_paths).to eq(['$[3]', '$[2]'])
      end

      it 'uses positive array index when array slice selector has negative range and step' do
        input = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        expect(Janeway.enum_for('$[-1:-3:-1]', input).find_paths).to eq(['$[9]', '$[8]'])
      end
    end

    # The remaining methods are provided by the Enumerable module.
    # These tests just confirm that the methods exist and work as expected for simple inputs

    describe '#map' do
      it 'transforms matched values' do
        input = [1, 2, 3]
        results = Janeway.enum_for('$.*', input).map { |v| v * 2 }
        expect(results).to eq([2, 4, 6])
      end
    end

    describe '#each_with_index' do
      context 'when input is an Array' do
        it 'returns values with index', skip: on_truffleruby do
          input = [1, 2, 3]
          results = Janeway.enum_for('$.*', input).each_with_index.to_a
          expect(results).to eq([[1, 0], [2, 1], [3, 2]])
        end
      end

      context 'when input is a Hash' do
        it 'returns values with index', skip: on_truffleruby do
          input = { 'a' => 1, 'b' => 2, 'c' => 3 }
          results = Janeway.enum_for('$.*', input).each_with_index.to_a
          expect(results).to eq([[1, 0], [2, 1], [3, 2]])
        end
      end
    end

    describe '#each_with_object' do
      it 'returns values with index', skip: on_truffleruby do
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
      it 'collects returned values that matched the condition', skip: on_truffleruby do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input)
        result = enum.select(&:odd?)
        expect(result).to eq([1, 3])
      end
    end

    describe '#reject' do
      it 'collects returned values that matched the condition', skip: on_truffleruby do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input)
        result = enum.reject(&:odd?)
        expect(result).to eq([2])
      end
    end

    describe '#filter_map', skip: on_truffleruby do
      it 'collects and modifies values return by the query' do
        input = { 'a' => 1, 'b' => 2, 'c' => 3 }
        enum = Janeway.enum_for('$.*', input)
        result = enum.filter_map { |value| value**2 if value.odd? }
        expect(result).to eq([1, 9])
      end
    end
  end
end
