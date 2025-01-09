# frozen_string_literal: true

require_relative 'lib/janeway/version'

Gem::Specification.new do |s|
  s.name = 'janeway'
  s.version = Janeway::VERSION
  s.required_ruby_version = '>= 2.7.0'
  s.authors = ['Fraser Hanson']
  s.email = ['fraser.hanson@gmail.com']
  s.description = <<~DESCRIPTION
    JSONPath is a query language for selecting and extracting values from a JSON text.
    It does for JSON the same job that XPath does for XML.
    This is a fast JSONPath parser in pure ruby.

    This jsonpath parser is:
      * a complete implementation of the JSONPath standard, IETF RFC 9535
      * based on the finalized RFC released in 2024, not an older draft (there were changes)
      * written in ruby 3 with frozen string literals

  DESCRIPTION

  s.files = Dir['{lib,bin}/**/*', 'LICENSE', 'README.md']
  s.executables = ['janeway']
  s.extra_rdoc_files = ['README.md']
  s.homepage = 'https://github.com/gongfarmer/janeway'
  s.licenses = ['MIT']
  s.summary = 'jsonpath parser which implements the finalized IETF standard of Goessner JSONPath'
end
