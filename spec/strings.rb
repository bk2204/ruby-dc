require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  def calc(options = {})
    @output = StringIO.new('', 'w')
    @input = StringIO.new('', 'r')
    DC::Calculator.new(@input, @output, options)
  end

  before :each do
    @calc = calc
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

  it "should compute (n % 256).chr for a (number, GNU)" do
    # GNU overrides FreeBSD in this case, because the behavior is more
    # consistent.
    [:gnu, :all].each do |ext|
      (0..1000).each do |n|
        c = calc(ext => true)
        c.parse("#{n}a")
        expect(c.stack).to eq [(n % 256).chr]
      end
    end
  end

  it "should compute (n % 256).chr for a (number, FreeBSD)" do
    [:freebsd].each do |ext|
      (0..1000).each do |n|
        c = calc(ext => true)
        c.parse("#{n}a")
        val = n % 256
        expect(c.stack).to eq [val == 0 ? '' : val.chr]
      end
    end
  end

  it "should take the first character for a (string)" do
    # GNU overrides FreeBSD in this case, because the behavior is more
    # consistent.
    [:gnu, :freebsd, :all].each do |ext|
      (1..255).each do |n|
        char = n.chr
        next if "[]".include? char
        c = calc(ext => true)
        c.parse("[#{char}ob]a")
        expect(c.stack).to eq [char]
      end
    end
  end
end
