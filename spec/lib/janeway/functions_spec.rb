# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Functions do
    describe '.translate_iregex_to_ruby_regex' do
      it 'accepts a range quantifier within the limits' do
        regexp = described_class.translate_iregex_to_ruby_regex('[0-9]{2,4}')
        expect(regexp).to match('123')
        expect(regexp).not_to match('12345')
      end

      it 'accepts a range quantifier on a group without a range quantifier inside' do
        regexp = described_class.translate_iregex_to_ruby_regex('(ab+){2,3}')
        expect(regexp).to match('ababb')
      end

      it 'accepts a non-range quantifier on a group with a range quantifier inside' do
        regexp = described_class.translate_iregex_to_ruby_regex('(a{2})*')
        expect(regexp).to match('aaaa')
      end

      it 'accepts an escaped brace that is not a range quantifier' do
        regexp = described_class.translate_iregex_to_ruby_regex('a\\{2\\}')
        expect(regexp).to match('a{2}')
      end

      it 'accepts a brace inside a character class' do
        regexp = described_class.translate_iregex_to_ruby_regex('[{}]{2}')
        expect(regexp).to match('{}')
      end

      it 'rejects a range quantifier with a large bound' do
        expect {
          described_class.translate_iregex_to_ruby_regex('a{20,200000}')
        }.to raise_error(Janeway::Error, /range quantifier bound 200000 is larger than 1000/)
      end

      it 'rejects a large lower bound without an upper bound' do
        expect {
          described_class.translate_iregex_to_ruby_regex('a{90000,}')
        }.to raise_error(Janeway::Error, /range quantifier bound 90000/)
      end

      it 'rejects a range quantifier on a group that contains a range quantifier' do
        expect {
          described_class.translate_iregex_to_ruby_regex('(a{2,4}){2,4}')
        }.to raise_error(Janeway::Error, /nested range quantifiers are not supported/)
      end

      it 'rejects a range quantifier on a group that contains a range quantifier in a subgroup' do
        expect {
          described_class.translate_iregex_to_ruby_regex('((a{2})b){3}')
        }.to raise_error(Janeway::Error, /nested range quantifiers/)
      end

      it 'rejects a regexp that is longer than the limit' do
        expect {
          described_class.translate_iregex_to_ruby_regex('a' * 10_001)
        }.to raise_error(Janeway::Error, /longer than 10000 characters/)
      end

      it 'passes an unclosed brace through unchanged' do
        regexp = described_class.translate_iregex_to_ruby_regex('a{2')
        expect(regexp).to match('a{2')
      end
    end
  end
end
