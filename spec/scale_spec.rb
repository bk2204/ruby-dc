require_relative 'spec_helper'

describe DC::Scale do
  it 'should respond to to_r' do
    s = DC::Scale.new(5)
    expect(s.to_r).to eq 5
    expect(s.to_r).to be_a Rational
  end

  it 'should respond to to_f' do
    s = DC::Scale.new(5)
    expect(s.to_f).to eq 5
    expect(s.to_f).to be_a Float
  end

  it 'should respond to to_i' do
    s = DC::Scale.new(5)
    expect(s.to_i).to eq 5
    expect(s.to_i).to be_an Integer
  end
end
