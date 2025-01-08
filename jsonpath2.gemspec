# frozen_string_literal: true

require_relative 'lib/jsonpath2/version'

Gem::Specification.new do |s|
  s.name = 'jsonpath2'
  s.version = JsonPath2::VERSION
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 3.1.0'
  s.authors = ['Fraser Hanson']
  s.description = <<~DESCRIPTION
    JsonPath is a query language for selecting and extracting values from a JSON text.
    It does for JSON what XPath does for XML.
    This is a fast JsonPath parser in pure ruby.

    This jsonpath parser is:
      * a complete implementation of the JsonPath standard, IETF RFC 9535
      * based on the finalized RFC released in 2024, not an older draft
      * built for ruby 3 with frozen string literals

  DESCRIPTION

  s.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH)
  s.bindir = 'exe'
  s.executables = []
  s.extra_rdoc_files = ['README.md']
  s.homepage = ''
  s.licenses = ['MIT']
  s.summary = 'jsonpath parser with strict RFC9535 compliance'

  s.add_dependency('json', '~> 2.3')
end
