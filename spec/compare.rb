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

  [
    [1, 2, '>', false],
    [1, 1, '>', false],
    [2, 1, '>', true],
    [1, 2, '<', true],
    [1, 1, '<', false],
    [2, 1, '<', false],
    [1, 2, '=', false],
    [1, 1, '=', true],
    [2, 1, '=', false]
  ].each do |a, b, op, val|
    it "should think #{a} #{op} #{b} is #{val}" do
      @calc.parse("#{@macro} #{a} #{b} #{op}a")
      expect(@calc.stack).to eq (val ? @trueval : @falseval)
    end

    it "should think #{a} !#{op} #{b} is #{!val}" do
      @calc.parse("#{@macro} #{a} #{b} !#{op}a")
      expect(@calc.stack).to eq (val ? @falseval : @trueval)
    end
  end
end
