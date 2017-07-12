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

  def generate_and_compare_range(s, scale)
    code = "s = Stub.new; s.scale = #{scale}; #{s}"
    calc = generate_and_run(code)
    ruby = eval(slurp + code) # rubocop:disable Lint/Eval
    range = 1 / (10.to_r**(scale - 1))
    expect(calc.stack[0]).to be_within(range).of(ruby)
  end

  def slurp
    return @ruby_mathlib if @ruby_mathlib
    filename = File.join(File.dirname(__FILE__), '../lib/dc/math/library.rb')
    @ruby_mathlib = File.new(filename).read
  end

  def calc
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    DC::Calculator.new(input, output, all: true)
  end

  def prime?(x)
    # SHA-512 uses primes up to 409; these values are therefore sufficient to
    # determine primality.
    [2, 3, 5, 7, 11, 13, 17, 19, 23].each do |p|
      return true if x == p
      return false if (x % p) == 0
    end
    true
  end

  it 'should generate proper exponential values for small values' do
    (1..10).each do |x|
      generate_and_compare_range "s.e(#{x})", 20
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
      generate_and_compare_range "s.e(#{x})", 20
      (1..10).each do |scale|
        s = Stub.new
        s.scale = scale
        expect(s.e(x)).to eq Math.exp(x).to_r.truncate(scale)
      end
    end
  end

  it 'should generate the SHA-512 round constants correctly' do
    mathlib = generate(slurp)
    values = %w[
      428A2F98D728AE22 7137449123EF65CD B5C0FBCFEC4D3B2F E9B5DBA58189DBBC
      3956C25BF348B538 59F111F1B605D019 923F82A4AF194F9B AB1C5ED5DA6D8118
      D807AA98A3030242 12835B0145706FBE 243185BE4EE4B28C 550C7DC3D5FFB4E2
      72BE5D74F27B896F 80DEB1FE3B1696B1 9BDC06A725C71235 C19BF174CF692694
      E49B69C19EF14AD2 EFBE4786384F25E3 0FC19DC68B8CD5B5 240CA1CC77AC9C65
      2DE92C6F592B0275 4A7484AA6EA6E483 5CB0A9DCBD41FBD4 76F988DA831153B5
      983E5152EE66DFAB A831C66D2DB43210 B00327C898FB213F BF597FC7BEEF0EE4
      C6E00BF33DA88FC2 D5A79147930AA725 06CA6351E003826F 142929670A0E6E70
      27B70A8546D22FFC 2E1B21385C26C926 4D2C6DFC5AC42AED 53380D139D95B3DF
      650A73548BAF63DE 766A0ABB3C77B2A8 81C2C92E47EDAEE6 92722C851482353B
      A2BFE8A14CF10364 A81A664BBC423001 C24B8B70D0F89791 C76C51A30654BE30
      D192E819D6EF5218 D69906245565A910 F40E35855771202A 106AA07032BBD1B8
      19A4C116B8D2D0C8 1E376C085141AB53 2748774CDF8EEB99 34B0BCB5E19B48A8
      391C0CB3C5C95A63 4ED8AA4AE3418ACB 5B9CCA4F7763E373 682E6FF3D6B2B8A3
      748F82EE5DEFB2FC 78A5636F43172F60 84C87814A1F0AB72 8CC702081A6439EC
      90BEFFFA23631E28 A4506CEBDE82BDE9 BEF9A3F7B2C67915 C67178F2E372532B
      CA273ECEEA26619C D186B8C721C0C207 EADA7DD6CDE0EB1E F57D4F7FEE6ED178
      06F067AA72176FBA 0A637DC5A2C898A6 113F9804BEF90DAE 1B710B35131C471B
      28DB77F523047D84 32CAAB7B40C72493 3C9EBE0A15C9BEBC 431D67C49C100D4C
      4CC5D4BECB3E42B6 597F299CFC657E2A 5FCB6FAB3AD6FAEC 6C44198C4A475817
    ]
    mathlib = generate(slurp)
    values.zip((2..409).select { |x| prime?(x) }).each do |(val, p)|
      val.gsub!(/^0+/, '')
      c = calc
      c.parse(mathlib)
      # Use scale 20 because 2^64 is approximately equal to 10^19.2.  Ensure
      # that more precision than that is not required for correctness.
      c.parse("25k 16o #{p} llx 3/ lex d 0k 1/- 2 64^* 1/p")
      expect(c.output.string).to eq("#{val}\n")
    end
  end

  it 'should not leave anything in registers after execution' do
    mathlib = generate(slurp)
    set = Set.new(%w[e l])
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
      # TODO: fix computation with scale of 20
      generate_and_compare "s.l(#{x})", 10
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
