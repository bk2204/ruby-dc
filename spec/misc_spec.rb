require_relative 'spec_helper'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should ignore comments" do
    @calc.parse("2 3 4# *\n+p")
    expect(@calc.stack).to eq [7, 2]
  end

  it 'should return false when exiting due to q' do
    expect(@calc.parse('[4 5 q]x')).to eq false
    expect(@calc.parse('4 5 q')).to eq false
  end

  it 'should return true when not exiting due to q' do
    expect(@calc.parse('[[4 5 q]x]x')).to eq true
    expect(@calc.parse('[[[4 5 q]x]x]x')).to eq true
  end

  it 'should not execute further instructions when leaving macros' do
    expect(@calc.parse('[[4 5 q]x *]x')).to eq true
    expect(@calc.stack).to eq [5, 4]
  end

  it 'should exit macros successfully with Q' do
    expect(@calc.parse('[4 5 1Q *]x')).to eq true
    expect(@calc.stack).to eq [5, 4]
  end

  it 'should exit multi-stage macros successfully with Q' do
    expect(@calc.parse('[[[4 5 3Q]x *]x 2 *]x 6')).to eq true
    expect(@calc.stack).to eq [6, 5, 4]
  end

  it 'should handle overly large level values with Q' do
    expect(@calc.parse('[[[4 5 4Q]x *]x 2 *]x 6')).to eq true
    expect(@calc.stack).to eq [6, 5, 4]
  end

  it 'should only exit the proper number of stages correctly' do
    expect(@calc.parse('[[[4 5 2Q]x *]x 2 *]x 6')).to eq true
    expect(@calc.stack).to eq [6, 10, 4]
  end

  it 'should return true when exiting normally' do
    expect(@calc.parse('[4 5 *]x')).to eq true
  end

  it 'should parse multiline strings properly' do
    code = "K 0k 2.0 1/ rkS@\nl@L@ R"
    calc = DC::Calculator.new(@input, @output, all: true)
    expect { calc.parse(code) }.not_to raise_exception
    expect(calc.stack).to eq [2]
  end

  it 'should not execute strings by default' do
    Dir.mktmpdir do |dir|
      calc = DC::Calculator.new(@input, @output, all: true)
      file = File.join(dir, 'foo')
      code = "! touch #{file}"
      expect { calc.parse(code) }.to raise_exception DC::InsecureCommandError
      expect { File.stat(file) }.to raise_exception Errno::ENOENT
      expect(calc.secure?).to eq true
    end
  end

  it 'should execute strings in insecure mode' do
    Dir.mktmpdir do |dir|
      calc = DC::Calculator.new(@input, @output, all: true, insecure: true)
      file = File.join(dir, 'foo')
      code = "! touch #{file}"
      expect { calc.parse(code) }.not_to raise_exception
      expect { File.stat(file) }.not_to raise_exception
      expect(calc.secure?).to eq false
    end
  end
end
