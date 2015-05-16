require_relative 'spec_helper'

describe DC::Generator do
  def generate_and_run(s)
    dc = DC::Generator.new.emit(s)
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    calc = DC::Calculator.new(input, output)
    calc.parse(dc)
    calc
  end

  def generate_and_compare(s)
    calc = generate_and_run(s)
    ruby = eval(s)
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
end
