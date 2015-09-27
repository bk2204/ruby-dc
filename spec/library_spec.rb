require_relative 'spec_helper'

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
  def generate_and_run(s)
    dc = DC::Generator.new(true).emit(s)
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    calc = DC::Calculator.new(input, output, all: true)
    calc.parse(dc)
    calc
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
end
