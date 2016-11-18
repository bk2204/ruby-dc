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

  it 'should parse strings in brackets' do
    @calc.parse('[hello]')
    expect(@calc.stack).to eq ['hello']
  end

  it 'should print strings in brackets with p' do
    @calc.parse('[hello]p')
    expect(@output.string).to eq "hello\n"
  end

  it 'should parse adjacent strings separately' do
    @calc.parse('[hello][goodbye]')
    expect(@calc.stack).to eq %w(goodbye hello)
  end

  it 'should parse strings with brackets in them' do
    @calc.parse('[hello[goodbye]]p')
    expect(@calc.stack).to eq ['hello[goodbye]']
    expect(@output.string).to eq "hello[goodbye]\n"
  end

  it 'should execute strings with x' do
    @calc.parse('[4 5*]x')
    expect(@calc.stack).to eq [20]
  end

  it 'should raise an exception for unbalanced brackets' do
    expect { @calc.parse('[hello]]p') }
      .to raise_exception(DC::UnbalancedBracketsError)
  end

  it 'should print a string without newlines for P' do
    @calc.parse('[hello]P')
    expect(@output.string).to eq 'hello'
  end

  it 'should convert numbers to strings and print for P' do
    @calc.parse('16i 48656C6C6F2C20776F726C64210A P')
    expect(@output.string).to eq "Hello, world!\n"
  end

  it 'should compute (n % 256).chr for a (number, GNU)' do
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

  it 'should compute (n % 256).chr for a (number, FreeBSD)' do
    [:freebsd].each do |ext|
      (0..1000).each do |n|
        c = calc(ext => true)
        c.parse("#{n}a")
        val = n % 256
        expect(c.stack).to eq [val == 0 ? '' : val.chr]
      end
    end
  end

  it 'should take the first character for a (string)' do
    # GNU overrides FreeBSD in this case, because the behavior is more
    # consistent.
    [:gnu, :freebsd, :all].each do |ext|
      (1..255).each do |n|
        char = n.chr
        next if '[]'.include? char
        c = calc(ext => true)
        c.parse("[#{char}ob]a")
        expect(c.stack).to eq [char]
      end
    end
  end

  it 'should do nothing with an empty string for a (string)' do
    # GNU overrides FreeBSD in this case, because the behavior is more
    # consistent.
    [:gnu, :freebsd, :all].each do |ext|
      c = calc(ext => true)
      c.parse('[]a')
      expect(c.stack).to eq ['']
    end
  end

  it 'should raise for a without extensions enabled' do
    expect { @calc.parse('1a') }.to \
      raise_exception(DC::UnsupportedExtensionError)
  end

  it 'should parse strings laid out over multiple calls to parse' do
    @calc.parse('[4 ')
    @calc.parse('5 *]x')
    @calc.parse('[7 ')
    @calc.parse('3 +')
    @calc.parse(']x')
    expect(@calc.stack).to eq [10, 20]
  end

  it 'should parse strings laid out over multiple lines' do
    @calc.parse("[4 \n5 *]x\n[7 3 +\n]x")
    expect(@calc.stack).to eq [10, 20]
  end

  it 'should parse nested strings laid out over multiple calls to parse' do
    @calc.parse("[[\n4 ")
    @calc.parse("5 *]\nx]x")
    @calc.parse("[\n[7 ")
    @calc.parse('3 +')
    @calc.parse(']x')
    @calc.parse(']x')
    expect(@calc.stack).to eq [10, 20]
  end

  it 'should read and execute a line with ?' do
    @input.string = "4 5 *\n6 *\n"
    @calc.parse('2 ? 3*p')
    expect(@calc.stack).to eq [60, 2]
    expect(@output.string).to eq "60\n"
  end
end
