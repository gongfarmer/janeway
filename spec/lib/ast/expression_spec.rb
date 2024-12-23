# frozen_string_literal: true

require 'jsonpath2/ast/expression'

module JsonPath2
  module AST
    describe Expression do
      let(:value) { '' }
      subject { described_class.new(value) }

      describe '#camelcase_to_underscore' do
        it 'converts camelCase string to lowercase with underscores' do
          %w[abcDef AbcDef].each do |str|
            expect(subject.camelcase_to_underscore(str)).to eq('abc_def')
          end
        end
        it 'does not change a lowercase string' do
          %w[abcdef abc_def _abc def_ ___].each do |str|
            expect(subject.camelcase_to_underscore(str)).to eq(str)
          end
        end
      end
    end
  end
end
