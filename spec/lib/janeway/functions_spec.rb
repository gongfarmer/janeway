# frozen_string_literal: true

require 'janeway'

module Janeway
  describe Functions do
    describe '.translate_iregex_to_ruby_regex' do
      it 'translates an I-Regexp to a Ruby Regexp' do
        regexp = described_class.translate_iregex_to_ruby_regex('[0-9]{2,4}')
        expect(regexp).to match('123')
        expect(regexp).not_to match('12345')
      end

      it 'anchors the pattern by default' do
        expect(described_class.translate_iregex_to_ruby_regex('a')).not_to match('xay')
      end

      it 'does not anchor the pattern when asked not to' do
        expect(described_class.translate_iregex_to_ruby_regex('a', anchor: false)).to match('xay')
      end

      it 'raises IRegexp::Invalid for a pattern that is not an I-Regexp' do
        expect { described_class.translate_iregex_to_ruby_regex('(?=a)a') }.to raise_error(IRegexp::Invalid)
      end

      it 'raises IRegexp::LimitExceeded for a pattern over a limit' do
        expect { described_class.translate_iregex_to_ruby_regex('a{1001}') }.to raise_error(IRegexp::LimitExceeded)
      end
    end
  end
end
