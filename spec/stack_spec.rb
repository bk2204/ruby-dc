require_relative 'spec_helper'

describe DC::Calculator do
  def calc(options = {})
    @output = StringIO.new('', 'w')
    @input = StringIO.new('', 'r')
    DC::Calculator.new(@input, @output, options)
  end

  before :each do
    @calc = calc
  end

  it 'should duplicate the top number on stack with d' do
    @calc.parse('3dpp')
    expect(@output.string).to eq "3\n3\n"
  end

  it 'should compute the correct value with duplicated value' do
    @calc.parse('1 3d *+p')
    expect(@output.string).to eq "10\n"
  end

  it 'should swap the top two values with r with extensions enabled' do
    %i[gnu freebsd].each do |ext|
      c = calc(ext => true)
      c.parse('1 2 3r')
      expect(c.stack).to eq [2, 3, 1]
    end
  end

  it 'should raise for r without extensions enabled' do
    expect { @calc.parse('1 2 3r') }
      .to raise_exception(DC::UnsupportedExtensionError)
  end

  it 'should push the current stack depth with z' do
    @calc.parse('zzzzz')
    expect(@calc.stack).to eq [4, 3, 2, 1, 0]
  end

  it 'should calculate correct stack depth at various points' do
    @calc.parse('3 5 z *- z')
    expect(@calc.stack).to eq [1, -7]
  end

  it 'should expose the stack through #stack' do
    @calc.parse('1 3d')
    expect(@calc.stack).to eq [3, 3, 1]
  end

  it 'should calculate the length of a string with Z' do
    @calc.parse('[abc123] Z')
    expect(@calc.stack).to eq [6]
  end

  it 'should calculate the length of a number with Z' do
    @calc.parse('1.2345 Z 2 Z .99 Z .000006 Z 1935.000 Z')
    expect(@calc.stack).to eq [7, 1, 2, 1, 5]
  end

  it 'should calculate the length of negative numbers with Z' do
    @calc.parse('_1.2345 Z _2 Z _.99 Z _.000006 Z _1935.000 Z')
    expect(@calc.stack).to eq [7, 1, 2, 1, 5]
  end

  it 'should print the top of stack with a newline with p (number)' do
    @calc.parse('1p')
    expect(@output.string).to eq "1\n"
    expect(@calc.stack).to eq [1]
  end

  it 'should print the top of stack with a newline with p (string)' do
    @calc.parse('[foo]p')
    expect(@output.string).to eq "foo\n"
    expect(@calc.stack).to eq ['foo']
  end

  it 'should print fractions properly with p' do
    @calc.parse('1.64p')
    expect(@output.string).to eq "1.64\n"
    expect(@calc.stack).to eq [1.64]
  end

  it 'should pop and print the top of stack with n (number)' do
    %i[gnu freebsd].each do |ext|
      c = calc(ext => true)
      c.parse('1n')
      expect(@output.string).to eq '1'
      expect(c.stack).to eq []
    end
  end

  it 'should pop and print the top of stack with n (string)' do
    %i[gnu freebsd].each do |ext|
      c = calc(ext => true)
      c.parse('[foo]n')
      expect(@output.string).to eq 'foo'
      expect(c.stack).to eq []
    end
  end

  it 'should print fractions properly with n' do
    %i[gnu freebsd all].each do |ext|
      c = calc(ext => true)
      c.parse('1.64n')
      expect(@output.string).to eq '1.64'
    end
  end

  it 'should raise for n without extensions enabled' do
    expect { @calc.parse('1n') }
      .to raise_exception(DC::UnsupportedExtensionError)
  end

  it 'should pop top of stack with R' do
    %i[freebsd all].each do |ext|
      c = calc(ext => true)
      c.parse('1 2 3R')
      expect(c.stack).to eq [2, 1]
    end
  end

  it 'should raise for R with only GNU extensions enabled' do
    c = calc(gnu: true)
    expect { c.parse('1R') }.to raise_exception(DC::UnsupportedExtensionError)
  end

  it 'should raise for R without extensions enabled' do
    expect { @calc.parse('1R') }
      .to raise_exception(DC::UnsupportedExtensionError)
  end

  it 'should print the entire stack without altering anything with f' do
    @calc.parse('1 2 [foo] 3f')
    expect(@output.string).to eq "3\nfoo\n2\n1\n"
    expect(@calc.stack).to eq [3, 'foo', 2, 1]
  end

  it 'should print fractions properly with f' do
    @calc.parse('4 2.53 1.64 17f')
    expect(@output.string).to eq "17\n1.64\n2.53\n4\n"
    expect(@calc.stack).to eq [17, 1.64, 2.53, 4]
  end

  it 'should load the default input base with I' do
    @calc.parse('I')
    expect(@calc.stack).to eq [10]
  end

  it 'should load the default output base with O' do
    @calc.parse('O')
    expect(@calc.stack).to eq [10]
  end

  it 'should load the default scale with K' do
    @calc.parse('K')
    expect(@calc.stack).to eq [0]
  end

  it 'should store the scale with k' do
    @calc.parse('4k K')
    expect(@calc.stack).to eq [4]
  end

  it 'should store the scale of the top of stack with X' do
    @calc.parse('0X 1.234X')
    expect(@calc.stack).to eq [3, 0]
  end

  it 'should raise an exception for invalid commands' do
    expect do
      @calc.parse('$')
    end.to raise_exception DC::InvalidCommandError
  end

  it 'should raise an exception with proper attributes for invalid commands' do
    begin
      @calc.parse('$')
    rescue DC::InvalidCommandError => e
      expect(e.command).to eq :"$"
    end
  end

  it 'should clear the stack with c' do
    @calc.parse('1 2 c 4 5')
    expect(@calc.stack).to eq [5, 4]
  end
end
