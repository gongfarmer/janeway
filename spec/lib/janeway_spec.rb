require 'janeway'

describe Janeway do
  describe '.path_to_diggable' do
    it 'converts singular query to an array of strings and integers' do
      expect(described_class.path_to_diggable('$.a[0].b[1].c')).to eq(['a', 0, 'b', 1, 'c'])
    end

    it 'accepts normalized form' do
      expect(described_class.path_to_diggable("$['a'][0]['b'][1]['c']")).to eq(['a', 0, 'b', 1, 'c'])
    end

    it 'raises error when given query is non-singular' do
      expect {
        described_class.path_to_diggable('$.a[1:2]')
      }.to raise_error(Janeway::Error, /Only a singular query can be converted to dig parameters/)
    end
  end
end
