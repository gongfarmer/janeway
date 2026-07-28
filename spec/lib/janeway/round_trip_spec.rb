# frozen_string_literal: true

require 'janeway'

# Regression guard: for every canonical query the following must hold:
#
#   * Parser.parse(q) does not raise
#   * Query#to_s does not raise
#   * Query#tree does not raise
#   * Parser.parse(Parser.parse(q).to_s).to_s == Parser.parse(q).to_s
#     (parse -> to_s is a fixed point after one round-trip)
#
# This is a coverage sweep across AST node types. Each new AST node type
# or `to_s` / `tree` change should add a canonical example here.
module Janeway
  describe 'query round-trip' do
    CANONICAL_QUERIES = [
      # Root
      '$',

      # Name selectors
      '$.a',
      '$.a.b.c',
      "$['a']",
      '$["a"]',

      # Index selectors
      '$[0]',
      '$[-1]',
      '$[10]',

      # Wildcard
      '$.*',
      '$[*]',
      '$.a[*]',
      '$.a.*',

      # Array slices
      '$[0:5]',
      '$[:5]',
      '$[5:]',
      '$[::2]',
      '$[::-1]',
      '$[1:5:2]',

      # Descendant segment
      '$..a',
      '$..*',
      '$..[0]',
      '$..[1,2]',

      # Child segment / union
      '$[0,1]',
      "$['a','b']",
      '$[1:3, 5]',

      # Filter selectors — comparisons
      '$[?@.x]',
      '$[?@.x == 1]',
      '$[?@.x != 1]',
      '$[?@.x > 1]',
      '$[?@.x < 1]',
      '$[?@.x >= 1]',
      '$[?@.x <= 1]',
      "$[?@.x == 'foo']",

      # Filter selectors — logical
      '$[?@.a && @.b]',
      '$[?@.a || @.b]',
      '$[?!@.x]',

      # Filter selectors — functions
      '$[?length(@.x) > 3]',
      '$[?count(@..*) > 0]',
      '$[?match(@.x, "^abc$")]',
      '$[?search(@.x, "abc")]',

      # Filter selectors — root reference
      '$[?@.x == $.y]',

      # Combined
      '$.store.book[*].author',
      '$..book[?@.price < 10]',
    ].freeze

    CANONICAL_QUERIES.each do |query|
      context "for #{query.inspect}" do
        it 'parses without raising' do
          expect { Parser.parse(query) }.not_to raise_error
        end

        it 'stringifies without raising' do
          expect { Parser.parse(query).to_s }.not_to raise_error
        end

        it 'produces a tree without raising' do
          expect { Parser.parse(query).tree }.not_to raise_error
        end

        it 'reaches a fixed point after one parse -> to_s round-trip' do
          first  = Parser.parse(query).to_s
          second = Parser.parse(first).to_s
          expect(second).to eq(first)
        end
      end
    end
  end
end
