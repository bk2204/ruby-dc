require_relative 'spec_helper'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should ignore comments" do
    @calc.parse("2 3 4# *\n+p")
    expect(@calc.stack).to eq [7, 2]
  end

  it 'should return false when exiting due to q' do
    expect(@calc.parse('[4 5 q]x')).to eq false
    expect(@calc.parse('4 5 q')).to eq false
  end

  it 'should return true when not exiting due to q' do
    expect(@calc.parse('[[4 5 q]x]x')).to eq true
    expect(@calc.parse('[[[4 5 q]x]x]x')).to eq true
  end

  it 'should not execute further instructions when leaving macros' do
    expect(@calc.parse('[[4 5 q]x *]x')).to eq true
    expect(@calc.stack).to eq [5, 4]
  end

  it 'should return true when exiting normally' do
    expect(@calc.parse('[4 5 *]x')).to eq true
  end
end
