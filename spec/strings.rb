require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should parse strings in brackets" do
    @calc.parse('[hello]')
    expect(@calc.stack).to eq ['hello']
  end

  it "should print strings in brackets with p" do
    @calc.parse('[hello]p')
    expect(@output.string).to eq "hello\n"
  end

  it "should parse adjacent strings separately" do
    @calc.parse('[hello][goodbye]')
    expect(@calc.stack).to eq ['goodbye', 'hello']
  end

  it "should parse strings with brackets in them" do
    @calc.parse('[hello[goodbye]]p')
    expect(@calc.stack).to eq ['hello[goodbye]']
    expect(@output.string).to eq "hello[goodbye]\n"
  end

  it "should execute strings with x" do
    @calc.parse('[4 5*]x')
    expect(@calc.stack).to eq [20]
  end

  it "should raise an exception for unbalanced brackets" do
    expect { @calc.parse('[hello]]p') }
      .to raise_exception(DC::UnbalancedBracketsError)
  end
end
