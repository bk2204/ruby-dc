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

  it 'should loop on strings properly' do
    # Print the numbers from 1 to 10.
    @calc.parse("[ln 1+ d sn p ln 10>b]sb")
    @calc.parse("0sn0")
    @calc.parse("lbx")
    expect(@output.string).to eq (1..10).map { |n| "#{n}\n" }.join('')
  end
end
