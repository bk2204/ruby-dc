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

  it "should duplicate the top number on stack with d" do
    @calc.parse('3dpp')
    expect(@output.string).to eq "3\n3\n"
  end

  it "should compute the correct value with duplicated value" do
    @calc.parse('1 3d *+p')
    expect(@output.string).to eq "10\n"
  end

  it "should swap the top two values with r with extensions enabled" do
    [:gnu, :freebsd].each do |ext|
      c = calc(ext => true)
      c.parse('1 2 3r')
      expect(c.stack).to eq [2, 3, 1]
    end
  end

  it "should raise for r without extensions enabled" do
    expect { @calc.parse('1 2 3r') }.to raise_exception(DC::UnsupportedExtensionError)
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

  it "should print the top of stack with a newline with p (number)" do
    @calc.parse('1p')
    expect(@output.string).to eq "1\n"
    expect(@calc.stack).to eq [1]
  end

  it "should print the top of stack with a newline with p (string)" do
    @calc.parse('[foo]p')
    expect(@output.string).to eq "foo\n"
    expect(@calc.stack).to eq ['foo']
  end

  it "should pop and print the top of stack with n (number)" do
    [:gnu, :freebsd].each do |ext|
      c = calc(ext => true)
      c.parse('1n')
      expect(@output.string).to eq '1'
      expect(c.stack).to eq []
    end
  end

  it "should pop and print the top of stack with n (string)" do
    [:gnu, :freebsd].each do |ext|
      c = calc(ext => true)
      c.parse('[foo]n')
      expect(@output.string).to eq 'foo'
      expect(c.stack).to eq []
    end
  end

  it "should raise for n without extensions enabled" do
    expect { @calc.parse('1n') }.to raise_exception(DC::UnsupportedExtensionError)
  end

  it "should pop top of stack with R" do
    [:freebsd, :all].each do |ext|
      c = calc(ext => true)
      c.parse('1 2 3R')
      expect(c.stack).to eq [2, 1]
    end
  end

  it "should raise for R with only GNU extensions enabled" do
    c = calc(gnu: true)
    expect { c.parse('1R') }.to raise_exception(DC::UnsupportedExtensionError)
  end

  it "should raise for R without extensions enabled" do
    expect { @calc.parse('1R') }.to raise_exception(DC::UnsupportedExtensionError)
  end

  it "should print the entire stack without altering anything with f" do
    @calc.parse('1 2 [foo] 3f')
    expect(@output.string).to eq "3\nfoo\n2\n1\n"
    expect(@calc.stack).to eq [3, 'foo', 2, 1]
  end

  it "should load the default input base with I" do
    @calc.parse('I')
    expect(@calc.stack).to eq [10]
  end

  it "should load the default output base with O" do
    @calc.parse('O')
    expect(@calc.stack).to eq [10]
  end
end
