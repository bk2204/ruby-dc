require_relative 'spec_helper'
require 'set'

# A stub object designed simply to make the same code work in dc as in Ruby.
class Stub < BasicObject
  def initialize
    @output = ::StringIO.new('', 'w+')
    @input = ::StringIO.new('', 'w+')
    @calc = ::DC::Calculator.new(@input, @output, all: true)
    @proxy = ::DC::Math::Library.new(@calc)
  end

  def method_missing(symbol, *args)
    if @proxy.respond_to? symbol
      @proxy.method(symbol).call(*args)
    else
      super
    end
  end

  def respond_to_missing?(symbol)
    @proxy.respond_to?(symbol) || super.respond_to?(symbol)
  end
end

describe DC::Generator do
  def generate(s)
    DC::Generator.new(true).emit(s)
  end

  def run(s)
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    calc = DC::Calculator.new(input, output, all: true)
    calc.parse(s)
    calc
  end

  def generate_and_run(s)
    dc = math_library + generate(s)
    run(dc)
  end

  def math_library
    return @mathlib if @mathlib
    @mathlib = generate(slurp)
  end

  def generate_and_compare(s, scale)
    code = "s = Stub.new; s.scale = #{scale}; #{s}"
    calc = generate_and_run(code)
    ruby = eval(slurp + code) # rubocop:disable Lint/Eval
    expect(calc.stack).to eq [ruby]
  end

  def slurp
    return @ruby_mathlib if @ruby_mathlib
    filename = File.join(File.dirname(__FILE__), '../lib/dc/math/library.rb')
    @ruby_mathlib = File.new(filename).read
  end

  it 'should generate proper exponential values for small values' do
    (1..10).each do |x|
      generate_and_compare "s.e(#{x})", 20
      (1..10).each do |scale|
        s = Stub.new
        s.scale = scale
        expect(s.e(x)).to eq Math.exp(x).to_r.truncate(scale)
      end
    end
  end

  it 'should generate proper exponential values for zero' do
    generate_and_compare 's.e(0)', 20
  end

  it 'should generate proper exponential values for negative values' do
    (-20..-1).each do |x|
      x /= 2
      generate_and_compare "s.e(#{x})", 20
      (1..10).each do |scale|
        s = Stub.new
        s.scale = scale
        expect(s.e(x)).to eq Math.exp(x).to_r.truncate(scale)
      end
    end
  end

  it 'should not leave anything in registers after execution' do
    mathlib = generate(slurp)
    set = Set.new(%w(e l))
    set.each do |f|
      calc = run(mathlib + "1l#{f}x")
      calc.registers.each do |i, reg|
        if set.include? i.chr
          expect(reg).to be_a Array
          expect(reg.length).to eq 1
          expect(reg[0]).to be_a String
        else
          expect(reg).to eq []
        end
      end
    end
  end

  it 'should generate proper natural log for small values' do
    (1..10).each do |x|
      x /= 2.0
      generate_and_compare "s.l(#{x})", 20
      s = Stub.new
      s.scale = 5
      expect(s.l(x)).to eq Math.log(x).to_r.truncate(s.scale)
    end
  end

  it 'should compute square roots accurately' do
    (1..10).each do |x|
      code_exp = generate(slurp) + " 10k 0.5 #{x} llx* lex 5k 1/p"
      code_sqrt = "5k #{x} vp"
      exp = run(code_exp).output.string.chomp.to_f
      sqrt = run(code_sqrt).output.string.chomp.to_f
      expect(exp).to be_within(0.000011).of(sqrt)
    end
  end

  it 'should generate properly formatted numbers for ln of fractional values' do
    code = generate(slurp) + ' 10k 0.5 llx 2*p'
    calc = run(code)
    expect(calc.output.string).to eq "-1.3862943610\n"
  end
end
