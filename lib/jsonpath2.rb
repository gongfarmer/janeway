require 'English'

# JsonPath2 jsonpath parsing library
module JsonPath2
  # JsonPath2 Abstract Syntax Tree
  module AST
  end
end

# Require ruby source files in the given dir. Do not recurse to subdirs.
# @param dir [String] dir path relative to __dir__
# @return [void]
def require_libs(dir)
  absolute_path = File.join(__dir__, dir)
  raise "No such dir: #{dir.inspect}" unless File.directory?(absolute_path)

  Dir.children(absolute_path).sort.each do |filename|
    abs_path = File.join(absolute_path, filename)
    next if File.directory?(abs_path)

    rel_path = File.join(dir, filename)
    require_relative(rel_path[0..-4])
  end
end

$LOAD_PATH << __dir__

# These are dependencies of the other AST source files, and must come first
require_relative 'jsonpath2/ast/shared/expression_collection'
require_relative 'jsonpath2/ast/expression'

require_libs('jsonpath2/ast')
require_libs('jsonpath2/error/runtime')
require_libs('jsonpath2/error/syntax')
