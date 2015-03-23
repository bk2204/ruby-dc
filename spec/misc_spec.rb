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
end
