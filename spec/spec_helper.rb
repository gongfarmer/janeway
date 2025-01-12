# frozen_string_literal: true

require 'simplecov'
SimpleCov.start if ENV['COVERAGE']

# If the ruby engine is truffleruby, return a string explaining why a unit test is being skipped.
# Otherwise, return nil.
#
# This is to allow tests to be skipped on truffleruby, which has some limitations.
#
# @return [String, nil]
def on_truffleruby
  return nil unless RUBY_ENGINE == 'truffleruby'

  'skipped on truffleruby due to integer size limit'
end

# Compliance Test Suite tests
CTS_DIR = File.expand_path("#{__dir__}/../jsonpath-compliance-test-suite/")
