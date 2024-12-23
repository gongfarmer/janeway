# frozen_string_literal: true

require_relative 'lib/jsonpath2/version'

Gem::Specification.new do |s|
  s.name = 'jsonpath2'
  s.version = JsonPath2::VERSION
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 3.1.0'
  s.authors = ['Fraser Hanson']
  s.description = <<~DESCRIPTION
    Fast jsonpath parser in pure ruby
  DESCRIPTION

  s.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH)
  s.bindir = 'exe'
  s.executables = []
  s.extra_rdoc_files = ['README.md']
  s.homepage = ''
  s.licenses = ['MIT']
  s.summary = 'ruby implementation of IETF Jsonpath standard'

  s.add_dependency('json', '~> 2.3')
end
