require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
    @macro = '7 [20]sa'
    # Values if the comparison is true or false, respectively.
    @trueval = [20, 7]
    @falseval = [7]
  end

  it "should not think 1 > 2" do
    @calc.parse("#{@macro} 1 2 >a")
    expect(@calc.stack).to eq @falseval
  end

  it "should think 2 > 1" do
    @calc.parse("#{@macro} 2 1 >a")
    expect(@calc.stack).to eq @trueval
  end

  it "should not think 1 !> 2" do
    @calc.parse("#{@macro} 1 2 !>a")
    expect(@calc.stack).to eq @trueval
  end

  it "should think 2 !> 1" do
    @calc.parse("#{@macro} 2 1 !>a")
    expect(@calc.stack).to eq @falseval
  end

  it "should think 1 < 2" do
    @calc.parse("#{@macro} 1 2 <a")
    expect(@calc.stack).to eq @trueval
  end

  it "should not think 2 < 1" do
    @calc.parse("#{@macro} 2 1 <a")
    expect(@calc.stack).to eq @falseval
  end

  it "should not think 1 !< 2" do
    @calc.parse("#{@macro} 1 2 !<a")
    expect(@calc.stack).to eq @falseval
  end

  it "should think 2 !< 1" do
    @calc.parse("#{@macro} 2 1 !<a")
    expect(@calc.stack).to eq @trueval
  end

  it "should not think 1 = 2" do
    @calc.parse("#{@macro} 1 2 =a")
    expect(@calc.stack).to eq @falseval
  end

  it "should think 1 = 1" do
    @calc.parse("#{@macro} 1 1 =a")
    expect(@calc.stack).to eq @trueval
  end

  it "should think 1 != 2" do
    @calc.parse("#{@macro} 1 2 !=a")
    expect(@calc.stack).to eq @trueval
  end

  it "should not think 1 != 1" do
    @calc.parse("#{@macro} 1 1 !=a")
    expect(@calc.stack).to eq @falseval
  end
end
