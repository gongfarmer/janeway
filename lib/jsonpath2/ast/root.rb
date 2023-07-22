class JsonPath2::AST::Root < JsonPath2::AST::Expression
  attr_accessor :expression

  def initialize(expr)
    @expression = expr
  end

  def ==(other)
    children == other&.children
  end

  def children
    [expression]
  end
end
