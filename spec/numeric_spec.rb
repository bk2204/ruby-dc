require_relative 'spec_helper'

describe DC::Numeric do
  it 'should convert values to Rationals with to_r' do
    [1, Rational(1, 2), 0.4].each do |value|
      n = DC::Numeric.new(value, 4, 4)
      expect(n.to_r).to be_a Rational
      expect(n.to_r).to eq value.to_r
    end
  end

  it 'should convert values to Integers with to_i' do
    [1, Rational(1, 2), 0.4].each do |value|
      n = DC::Numeric.new(value, 4, 4)
      expect(n.to_i).to be_an Integer
      expect(n.to_i).to eq value.to_i
    end
  end
end
