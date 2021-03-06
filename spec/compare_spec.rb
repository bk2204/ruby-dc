require_relative 'spec_helper'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
    @extcalc = DC::Calculator.new(@input, @output, freebsd: true)
    @macro = '7 [20]sa'
    # Values if the comparison is true or false, respectively.
    @trueval = [20, 7]
    @falseval = [7]
  end

  [
    [1, 2, '>', true],
    [1, 1, '>', false],
    [2, 1, '>', false],
    [1, 2, '<', false],
    [1, 1, '<', false],
    [2, 1, '<', true],
    [1, 2, '=', false],
    [1, 1, '=', true],
    [2, 1, '=', false],
  ].each do |a, b, op, val|
    it "should think #{a} #{op} #{b} is #{val}" do
      @calc.parse("#{@macro} #{a} #{b} #{op}a")
      expected = val ? @trueval : @falseval
      expect(@calc.stack).to eq expected
    end

    it "should think #{a} !#{op} #{b} is #{!val}" do
      @calc.parse("#{@macro} #{a} #{b} !#{op}a")
      expected = val ? @falseval : @trueval
      expect(@calc.stack).to eq expected
    end
  end

  [
    [1, 2, '{', 0],
    [1, 1, '{', 1],
    [2, 1, '{', 1],
    [1, 2, '(', 0],
    [1, 1, '(', 0],
    [2, 1, '(', 1],
    [1, 2, 'G', 0],
    [1, 1, 'G', 1],
    [2, 1, 'G', 0],
  ].each do |a, b, op, val|
    it "should push #{val} for #{a} #{b} #{op}" do
      @extcalc.parse("#{a} #{b} #{op}")
      expect(@extcalc.stack).to eq [val]
    end
  end

  it 'should invoke register a for 1 2>a' do
    @calc.parse('[[hello]p]sa 1 2>a')
    expect(@output.string).to eq "hello\n"
  end

  it 'should not invoke register a for 2 1>a' do
    @calc.parse('[[hello]p]sa 2 1>a')
    expect(@output.string).to eq ''
  end

  it 'should negate top of stack for N' do
    @extcalc.parse('1 N')
    expect(@extcalc.stack).to eq [0]

    @extcalc.parse('R 0 N')
    expect(@extcalc.stack).to eq [1]
  end
end
