# frozen_string_literal: true

require 'janeway'

module Janeway
  module AST
    describe Function do
      it 'raises when body arity does not match parameter count' do
        expect {
          Function.new('bad', [1, 2]) { |only_one_param| only_one_param }
        }.to raise_error(ArgumentError, /body arity 1 does not match parameter count 2/)
      end

      it 'accepts a body whose arity matches the parameter count' do
        expect {
          Function.new('ok', [1, 2]) { |a, b| a + b }
        }.not_to raise_error
      end

      it 'raises when body is not a Proc' do
        expect {
          Function.new('bad', [])
        }.to raise_error(ArgumentError, /expect body to be a Proc/)
      end

      it 'raises when name is not a string' do
        expect {
          Function.new(:bad, []) { }
        }.to raise_error(ArgumentError, /expect string/)
      end
    end
  end
end
