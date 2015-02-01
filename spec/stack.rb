require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should duplicate the top number on stack with d" do
    @calc.parse('3dpp')
    expect(@output.string).to eq "3\n3\n"
  end

  it "should compute the correct value with duplicated value" do
    @calc.parse('1 3d *+p')
    expect(@output.string).to eq "10\n"
  end

  it "should expose the stack through #stack" do
    @calc.parse('1 3d')
    expect(@calc.stack).to eq [3, 3, 1]
  end
end
