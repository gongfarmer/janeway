# frozen_string_literal: true

require 'janeway'

module Janeway
  module AST
    describe Function do
      it 'raises when the parameter count does not match the registered arity' do
        expect {
          Function.new('count', [1, 2])
        }.to raise_error(ArgumentError, /declared arity 1 does not match parameter count 2/)
      end

      it 'accepts the correct number of parameters' do
        expect {
          Function.new('count', [1])
        }.not_to raise_error
      end

      it 'raises when the function name is not in the registry' do
        expect {
          Function.new('not_a_real_function', [])
        }.to raise_error(ArgumentError, /unknown function/)
      end

      it 'raises when name is not a string' do
        expect {
          Function.new(:count, [1])
        }.to raise_error(ArgumentError, /expect string/)
      end

      it 'reports literal? based on the registry entry' do
        expect(Function.new('count', [1]).literal?).to be(true)
        expect(Function.new('match', %w[x y]).literal?).to be(false)
      end
    end
  end
end
