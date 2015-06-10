require_relative 'spec_helper'

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

  it 'should be able to handle array operations' do
    @calc.parse('[a] 0:a [c] Sa [b] 0:a 0;a p La 0;a p')
    expect(@output.string).to eq "b\na\n"
  end

  it 'should put a zero on the stack when no value exists' do
    @calc.parse('0;a')
    expect(@calc.stack).to eq [0]
  end

  it 'should push and pop arrays with s and l' do
    # Example from mks's dc man page.
    @calc.parse('11 sa 12 1:a la p 1;a pc 0 Sa la p 1;a p La la p 1;a p')
    expect(@output.string).to eq "11\n12\n0\n0\n11\n12\n"
    expect(@calc.stack).to eq [12, 11, 0, 0, 0]
    expect(@calc.registers['a'.ord]).to eq [11]
    expect(@calc.arrays['a'.ord]).to eq [nil, 12]
  end
end
