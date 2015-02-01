require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should be able to store a number in a register" do
    expect { @calc.parse('2 sr') }.not_to raise_exception
  end

  it "should be able to load a number in a register" do
    @calc.parse('2 sr lrp')
    expect(@output.string).to eq "2\n"
  end

  it "should always load from the top with l" do
    @calc.parse('2 Sr 3 Sr lrp lrp')
    expect(@output.string).to eq "3\n3\n"
  end

  it "should be able to push and pop multiple numbers in a register" do
    @calc.parse('2 Sr 3 Sr Lrp Lrp')
    expect(@output.string).to eq "3\n2\n"
  end

  it "should have independent registers" do
    @calc.parse('2 Sa 3 Sb Lap')
    expect(@output.string).to eq "2\n"
  end

  it "should expose registers through #registers" do
    @calc.parse('2 Sa 4 Sa 3 Sb 9 Sb')
    expect(@calc.registers['a'.ord]).to eq [4, 2]
    expect(@calc.registers['b'.ord]).to eq [9, 3]
  end
end
