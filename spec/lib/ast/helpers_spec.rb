# frozen_string_literal: true

require 'janeway/ast/helpers'

module Janeway
  module AST
    describe Helpers do
      describe '#camelcase_to_underscore' do
        it 'converts camelCase string to lowercase with underscores' do
          %w[abcDef AbcDef].each do |str|
            expect(described_class.camelcase_to_underscore(str)).to eq('abc_def')
          end
        end

        it 'does not change a lowercase string' do
          %w[abcdef abc_def _abc def_ ___].each do |str|
            expect(described_class.camelcase_to_underscore(str)).to eq(str)
          end
        end
      end
    end
  end
end
