class JsonPath2::AST::String < JsonPath2::AST::Expression
  def initialize(val)
    super(val)
  end

  def ==(other)
    value == other&.value
  end

  def children
    []
  end
end
