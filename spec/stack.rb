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

  it "should swap the top two values with r" do
    @calc.parse('1 2 3r')
    expect(@calc.stack).to eq [2, 3, 1]
  end

  it "should push the current stack depth with z" do
    @calc.parse('zzzzz')
    expect(@calc.stack).to eq [4, 3, 2, 1, 0]
  end

  it "should calculate correct stack depth at various points" do
    @calc.parse('3 5 z *- z')
    expect(@calc.stack).to eq [1, -7]
  end

  it "should expose the stack through #stack" do
    @calc.parse('1 3d')
    expect(@calc.stack).to eq [3, 3, 1]
  end
end
