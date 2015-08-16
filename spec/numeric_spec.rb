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

  it 'should convert values to Floats with to_f' do
    [1, Rational(1, 2), 0.4].each do |value|
      n = DC::Numeric.new(value, 4, 4)
      expect(n.to_f).to be_a Float
      expect(n.to_f).to eq value.to_f
    end
  end

  it 'should implement respond_to? correctly' do
    n = DC::Numeric.new(2, 4, 4)
    expect(n).to respond_to :ceil
    expect(n).to respond_to :to_i
    expect(n).not_to respond_to :lalala
  end
end
