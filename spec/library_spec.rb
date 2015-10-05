require_relative 'spec_helper'
require 'set'

class Stub < BasicObject
  def initialize
    @output = ::StringIO.new('', 'w+')
    @input = ::StringIO.new('', 'w+')
    @calc = ::DC::Calculator.new(@input, @output, all: true)
    @proxy = ::DC::Math::Library.new(@calc)
  end

  def method_missing(symbol, *args)
    @proxy.method(symbol).call(*args)
  end

  def respond_to?(symbol)
    @proxy.respond_to?(symbol)
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
    dc = generate(s)
    run(dc)
  end

  def generate_and_compare(s)
    code = "#{slurp}\n#{s}"
    calc = generate_and_run(code)
    ruby = eval(code)  # rubocop:disable Lint/Eval
    expect(calc.stack).to eq [ruby]
  end

  def slurp
    filename = File.join(File.dirname(__FILE__), '../lib/dc/math/library.rb')
    File.new(filename).read
  end

  it 'should generate proper exponential values for small values' do
    (1..10).each do |x|
      generate_and_compare "s = Stub.new; s.scale = 20; s.e(#{x})"
      (1..10).each do |scale|
        s = Stub.new
        s.scale = scale
        expect(s.e(x)).to eq Math.exp(x).to_r.truncate(scale)
      end
    end
  end

  it 'should generate proper exponential values for zero' do
    generate_and_compare "s = Stub.new; s.scale = 20; s.e(0)"
  end

  it 'should generate proper exponential values for negative values' do
    (-20..-1).each do |x|
      x /= 2
      generate_and_compare "s = Stub.new; s.scale = 20; s.e(#{x})"
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
      generate_and_compare "s = Stub.new; s.scale = 20; s.l(#{x})"
      s = Stub.new
      s.scale = 5
      expect(s.l(x)).to eq Math.log(x).to_r.truncate(s.scale)
    end
  end
end
