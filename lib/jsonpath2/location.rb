# frozen_string_literal: true

Location = Struct.new(:col, :length) do
  def ==(other)
    col == other.col && length == other.length
  end
end
