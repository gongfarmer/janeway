# frozen_string_literal: true

Location = Struct.new(:line, :col, :length) do
  def ==(other)
    line == other.line &&
      col == other.col &&
      length == other.length
  end
end
