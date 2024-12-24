# frozen_string_literal: true

require 'jsonpath2/lexer'

module JsonPath2
  describe Lexer do
    it 'accepts multiple selectors within brackets, comma-separated' do
      expect(Lexer.lex('$[1, 2]')).to eq([:'$', :'[', 1, :',', 2, :']', :eof])
    end
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
      # Escaping rules are defined here:
      # https://ietf-wg-jsonpath.github.io/draft-ietf-jsonpath-base/draft-ietf-jsonpath-base.html#name-semantics-3
      it 'converts chars \b to backspace' do
        expect(Lexer.lex('$.["\b"]')).to eq([:'$', :'.', :'[', "\b", :']', :eof])
      end
      it 'converts chars \t to tab' do
        expect(Lexer.lex('$.["\t"]')).to eq([:'$', :'.', :'[', "\t", :']', :eof])
      end
      it 'converts chars \n to line feed' do
        expect(Lexer.lex('$.["\n"]')).to eq([:'$', :'.', :'[', "\n", :']', :eof])
      end
      it 'converts chars \f to form feed' do
        expect(Lexer.lex('$.["\f"]')).to eq([:'$', :'.', :'[', "\f", :']', :eof])
      end
      it 'converts chars \r to carriage return' do
        expect(Lexer.lex('$.["\r"]')).to eq([:'$', :'.', :'[', "\r", :']', :eof])
      end
      it 'converts chars \" to double quote, inside double quotes' do
        expect(Lexer.lex('$.["\""]')).to eq([:'$', :'.', :'[', '"', :']', :eof])
      end
      it "converts chars \' to apostrophe, inside single quotes" do
        expect(Lexer.lex("$.['\\'']")).to eq([:'$', :'.', :'[', "'", :']', :eof])
      end
      it 'converts chars \\ to backslash' do
        expect(Lexer.lex('$.["\\\\"]')).to eq([:'$', :'.', :'[', '\\', :']', :eof])
      end
      it 'converts hexadecimal escape in uppercase to unicode' do
        expect(Lexer.lex('$.["\u263A"]')).to eq([:'$', :'.', :'[', '☺', :']', :eof])
      end
      it 'converts hexadecimal escape in lowercase to unicode' do
        expect(Lexer.lex('$.["\u263a"]')).to eq([:'$', :'.', :'[', '☺', :']', :eof])
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
