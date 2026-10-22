# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Parser do
    # A literal pattern that is over an I-Regexp limit is rejected when the query is parsed.
    # These examples call the parser directly: going through Interpreter.interpret would also pass
    # if the pattern were only rejected when the interpreter is built.
    %w[match search].each do |function|
      describe "#{function}() with a literal pattern" do
        def parse_pattern(function, pattern)
          described_class.parse(%($[?#{function}(@.a, "#{pattern}")]))
        end

        it 'rejects a range quantifier with a large bound' do
          expect { parse_pattern(function, 'a{1001}') }.to raise_error(Janeway::Error, /repeat count 1001 exceeds 1000/)
        end

        it 'rejects a range quantifier with a large bound and no upper bound' do
          expect { parse_pattern(function, 'a{90000,}') }.to raise_error(Janeway::Error, /repeat count 90000/)
        end

        it 'rejects a range quantifier on a group that contains a range quantifier' do
          expect { parse_pattern(function, '(a{2}){2}') }.to raise_error(Janeway::Error, /group that contains a range/)
        end

        it 'rejects a pattern that is too long' do
          expect { parse_pattern(function, 'a' * 10_001) }.to raise_error(Janeway::Error, /longer than 10000/)
        end

        it 'rejects groups that are nested too deeply' do
          expect { parse_pattern(function, "#{'(' * 101}#{')' * 101}") }.to raise_error(Janeway::Error, /nested deeper/)
        end

        it 'includes the query in the error' do
          expect { parse_pattern(function, 'a{1001}') }.to raise_error(Janeway::Error) { |error|
            expect(error.query).to eq(%($[?#{function}(@.a, "a{1001}")]))
          }
        end

        it 'points at the problem in the query' do
          query = %($[?#{function}(@.a, "ab{1001}")])
          expect { described_class.parse(query) }.to raise_error(Janeway::Error) { |error|
            expect(query[error.location.col, error.location.length]).to eq('1001')
          }
        end

        ['("ab{1001}")', '(("ab{1001}"))'].each do |literal|
          it "points at the problem in the parenthesised literal #{literal}" do
            query = %($[?#{function}(@.a, #{literal})])
            expect { described_class.parse(query) }.to raise_error(Janeway::Error) { |error|
              expect(query[error.location.col, error.location.length]).to eq('1001')
            }
          end
        end

        it 'points at the problem after an escape sequence in the string' do
          query = %($[?#{function}(@.a, 'it\\'s{1001}')])
          expect { described_class.parse(query) }.to raise_error(Janeway::Error) { |error|
            expect(query[error.location.col, error.location.length]).to eq('1001')
          }
        end

        it 'points at the whole string when the problem has no single position' do
          query = %($[?#{function}(@.a, "#{'a' * 10_001}")])
          expect { described_class.parse(query) }.to raise_error(Janeway::Error) { |error|
            expect(error.location.col).to eq(query.index('"'))
            expect(error.location.length).to eq(10_003)
          }
        end

        it 'accepts a pattern that is not an I-Regexp, which gives LogicalFalse' do
          expect { parse_pattern(function, '(?=a)a') }.not_to raise_error
        end

        it 'accepts a pattern that is not an I-Regexp and is also over a limit' do
          expect { parse_pattern(function, 'a{1001}(') }.not_to raise_error
        end

        it 'accepts a pattern at the limits' do
          expect { parse_pattern(function, 'a{1000}') }.not_to raise_error
        end

        it 'accepts a pattern taken from the input document' do
          expect { described_class.parse("$[?#{function}(@.a, $.b)]") }.not_to raise_error
        end
      end
    end
  end
end
