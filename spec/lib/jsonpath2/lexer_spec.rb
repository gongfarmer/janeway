# frozen_string_literal: true

require 'jsonpath2/lexer'

module JsonPath2
  describe Lexer do
    context 'when tokenizing name selector' do
      it 'tokenizes name selector' do
        expect(Lexer.lex('$.name')).to eq([:'$', :'.', 'name', :eof])
      end
      it 'accepts double quotes around name' do
        expect(Lexer.lex('$.["a a"]')).to eq([:'$', :'.', :'[', 'a a', :']', :eof])
      end
      it 'accepts quotes around name' do
        expect(Lexer.lex("$.['a a']")).to eq([:'$', :'.', :'[', 'a a', :']', :eof])
      end
      it 'accepts name with @ in quotes' do
        expect(Lexer.lex('$.["@"]')).to eq([:'$', :'.', :'[', '@', :']', :eof])
      end
      it 'accepts name with . in quotes' do
        expect(Lexer.lex('$.["a.b"]')).to eq([:'$', :'.', :'[', 'a.b', :']', :eof])
      end
    end
    context 'when tokenizing index selector' do
      it 'tokenizes index selector' do
        expect(Lexer.lex('$[0]')).to eq([:'$', :'[', 0, :']', :eof])
      end
      it 'handles multi digit indices' do
        expect(Lexer.lex('$[987]')).to eq([:'$', :'[', 987, :']', :eof])
      end
      it 'handles negative indices' do
        expect(Lexer.lex('$[-123]')).to eq([:'$', :'[', :'-', 123, :']', :eof])
      end
    end
    it 'tokenizes array slice selector' do
      expect(Lexer.lex('$[1:3]')).to eq([:'$', :'[', 1, :':', 3, :']', :eof])
      expect(Lexer.lex('$[5:]')).to eq([:'$', :'[', 5, :':', :']', :eof])
      expect(Lexer.lex('$[1:5:2]')).to eq([:'$', :'[', 1, :':', 5, :':', 2, :']', :eof])
      expect(Lexer.lex('$[5:1:-2]')).to eq([:'$', :'[', 5, :':', 1, :':', :'-', 2, :']', :eof])
      expect(Lexer.lex('$[::-1]')).to eq([:'$', :'[', :':', :':', :'-', 1, :']', :eof])
    end
  end
end
