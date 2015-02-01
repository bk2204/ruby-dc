require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should add two numbers with +" do
    @calc.parse('1 2 +p')
    expect(@output.string).to eq "3\n"
  end

  it "should subtract two numbers with -" do
    @calc.parse('2 1 -p')
    expect(@output.string).to eq "1\n"
  end

  it "should handle negative results from subtraction" do
    @calc.parse('3 5 -p')
    expect(@output.string).to eq "-2\n"
  end
end
