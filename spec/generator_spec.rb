require_relative 'spec_helper'

describe DC::Generator do
  def generate_and_run(s)
    dc = DC::Generator.new.emit(s)
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    calc = DC::Calculator.new(input, output, all: true)
    calc.parse(dc)
    calc
  end

  def generate_and_compare(s)
    calc = generate_and_run(s)
    ruby = eval(s)  # rubocop:disable Lint/Eval
    expect(calc.stack).to eq [ruby]
  end

  it 'should generate proper results for small integer arithmetic' do
    (-2..2).each do |x|
      (-2..2).each do |y|
        [:+, :-, :*].each do |op|
          generate_and_compare "#{x} #{op} #{y}"
        end
      end
    end
  end

  it 'should generate proper results for assignment operators' do
    (-2..2).each do |x|
      generate_and_compare "x = #{x}; x"
    end
  end

  it 'should generate proper results for assignment operators' do
    (-2..2).each do |x|
      (-2..2).each do |y|
        [:+, :-, :*].each do |op|
          generate_and_compare "x = #{x}; x #{op}= #{y}"
        end
      end
    end
  end

  it 'should treat to_r as a no-op' do
    generate_and_compare 'x = 1.to_r; x'
    generate_and_compare 'x = 1; y = x.to_r'
    generate_and_compare 'x = 1; x.to_r'
  end

  it 'should truncate values with to_i' do
    (-20..20).each do |x|
      generate_and_compare "x = #{x / 10.0}.to_i; x"
      generate_and_compare "#{x / 10.0}.to_i"
    end
  end

  it 'should call functions correctly' do
    generate_and_compare "def e(x); y = x + 1; y; end; e(2)"
    generate_and_compare "def e(x); x + 1; end; e(2)"
  end

  it 'should raise when function names are too long' do
    expect do
      generate_and_compare 'def foo(x); y = x + 1; y; end; foo(2)'
    end.to raise_exception(DC::InvalidNameError, /single character/)
  end

  it 'should be able to handle Integer#times' do
    code = <<-EOM
    n = 0
    25.times { |i| n += i + 1 }
    n
    EOM
    generate_and_compare code
  end
end
