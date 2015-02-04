require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should not think 1 > 2" do
    @calc.parse('7 [20]sa 1 2 >a')
    expect(@calc.stack).to eq [7]
  end

  it "should think 2 > 1" do
    @calc.parse('7 [20]sa 2 1 >a')
    expect(@calc.stack).to eq [20, 7]
  end

  it "should not think 1 !> 2" do
    @calc.parse('7 [20]sa 1 2 !>a')
    expect(@calc.stack).to eq [20, 7]
  end

  it "should think 2 !> 1" do
    @calc.parse('7 [20]sa 2 1 !>a')
    expect(@calc.stack).to eq [7]
  end

  it "should think 1 < 2" do
    @calc.parse('7 [20]sa 1 2 <a')
    expect(@calc.stack).to eq [20, 7]
  end

  it "should not think 2 < 1" do
    @calc.parse('7 [20]sa 2 1 <a')
    expect(@calc.stack).to eq [7]
  end

  it "should not think 1 !< 2" do
    @calc.parse('7 [20]sa 1 2 !<a')
    expect(@calc.stack).to eq [7]
  end

  it "should think 2 !< 1" do
    @calc.parse('7 [20]sa 2 1 !<a')
    expect(@calc.stack).to eq [20, 7]
  end

  it "should not think 1 = 2" do
    @calc.parse('7 [20]sa 1 2 =a')
    expect(@calc.stack).to eq [7]
  end

  it "should think 1 = 1" do
    @calc.parse('7 [20]sa 1 1 =a')
    expect(@calc.stack).to eq [20, 7]
  end

  it "should think 1 != 2" do
    @calc.parse('7 [20]sa 1 2 !=a')
    expect(@calc.stack).to eq [20, 7]
  end

  it "should not think 1 != 1" do
    @calc.parse('7 [20]sa 1 1 !=a')
    expect(@calc.stack).to eq [7]
  end
end
