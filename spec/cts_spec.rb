# frozen_string_literal: true

require 'rspec'
require 'json'
require 'janeway'

# Shim that reads tests from the jsonpath compliance test suite and runs them as rspec tests

shared_examples 'a query that returns a result' do |test_name, selector, input, expected|
  it "returns the expected result for #{test_name}" do
    results = Janeway.on(selector, input).search
    expect(results).to eq(expected)
  end
end

shared_examples 'a query that returns a non-deterministic result' do |test_name, selector, input, expected|
  it "returns an expected result for #{test_name}" do
    results = Janeway.on(selector, input).search
    expect(expected).to include(results)
  end
end

shared_examples 'an invalid query' do |test_name, selector|
  it "raises parse error for #{test_name}" do
    expect {
      Janeway.compile(selector)
    }.to raise_error(Janeway::Error)
  end
end

# Run each test from the compliance test suite.
# The CTS has 3 types of tests:
# * invalid selector -- the query is invalid and should cause a parse error
# * non-deterministic -- several query results are possible and accepted
# * regular -- only one query result is accepted

CTS_PATH = "#{CTS_DIR}/cts.json".freeze
COMPLIANCE_TESTS = File.exist?(CTS_PATH) ? JSON.parse(File.read(CTS_PATH)) : { 'tests' => [] }
describe Janeway do
  COMPLIANCE_TESTS['tests'].each do |test|
    name = test['name']
    query = test['selector']
    input = test['document']
    if test['invalid_selector']
      it_behaves_like 'an invalid query', name, query
    elsif test['result']
      it_behaves_like 'a query that returns a result', name, query, input, test['result']
    else
      it_behaves_like 'a query that returns a non-deterministic result', name, query, input, test['results']
    end
  end
end
