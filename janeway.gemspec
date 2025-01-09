# frozen_string_literal: true

require_relative 'lib/janeway/version'

Gem::Specification.new do |s|
  s.name = 'janeway'
  s.version = Janeway::VERSION
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 3.1.0'
  s.authors = ['Fraser Hanson']
  s.description = <<~DESCRIPTION
    JsonPath is a query language for selecting and extracting values from a JSON text.
    It does for JSON what XPath does for XML.
    This is a fast JsonPath parser in pure ruby.

    This jsonpath parser is:
      * a complete implementation of the JsonPath standard, IETF RFC 9535
      * based on the finalized RFC released in 2024, not an older draft (there were changes)
      * written in ruby 3 with frozen string literals

  DESCRIPTION

  s.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH)
  s.bindir = 'exe'
  s.executables = []
  s.extra_rdoc_files = ['README.md']
  s.homepage = ''
  s.licenses = ['MIT']
  s.summary = 'jsonpath parser which implements the final IETF standard of Goessner JSONPath'

  s.add_dependency('json', '~> 2.3')
end
