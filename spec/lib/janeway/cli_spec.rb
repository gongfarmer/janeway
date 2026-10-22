# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'

module Janeway
  describe 'bin/janeway' do
    let(:lib_dir) { File.expand_path('../../../lib', __dir__) }
    let(:script) { File.expand_path('../../../bin/janeway', __dir__) }

    # Run the command line tool, with the data on stdin so that nothing waits on a terminal.
    # @return [Array(String, String, Integer)] stdout, stderr, exit status
    def run_cli(query, data)
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I#{lib_dir}", script, query, stdin_data: data)
      [stdout, stderr, status.exitstatus]
    end

    # @return [Array<String>] the lines of stderr that are only spaces and carets
    def pointer_lines(stderr)
      stderr.lines.map(&:chomp).grep(/\A *\^+\z/)
    end

    it 'prints the query only as the message does, with a pointer, for a lexer error' do
      query = '$.a[?@.b ~~ 1]'
      _, stderr, status = run_cli(query, '{"a":[1]}')
      expect(status).to eq(1)
      expect(stderr.scan(query).size).to eq(2) # the message header, and its pointer block
      expect(pointer_lines(stderr).size).to eq(1)
    end

    it 'points at the whole repeat count of an over-limit pattern' do
      query = '$[?match(@, "ab{1001}c")]'
      _, stderr, status = run_cli(query, '["a"]')
      expect(status).to eq(1)
      expect(stderr).to include('repeat count 1001 exceeds 1000')
      expect(stderr.scan(query).size).to eq(2) # the message header, and its pointer block
      expect(pointer_lines(stderr).map { _1.count('^') }).to eq([4])
    end

    it 'prints no empty Query line for an error that has no query' do
      _, stderr, status = run_cli('$[?match(@.a)]', '{"a":1}')
      expect(status).to eq(1)
      expect(stderr).to include('Not enough parameters for match()')
      expect(stderr.lines.map(&:strip)).not_to include('Query:')
    end

    it 'prints the query once for an error that has a query and no location' do
      query = '$.a)'
      _, stderr, status = run_cli(query, '{"a":[1]}')
      expect(status).to eq(1)
      expect(stderr.scan(query).size).to eq(1)
    end

    it 'prints the results as JSON for a valid query' do
      stdout, _, status = run_cli('$.a', '{"a":[1]}')
      expect(status).to eq(0)
      expect(JSON.parse(stdout)).to eq([[1]])
    end
  end
end
