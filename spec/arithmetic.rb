require 'stringio'

require_relative '../lib/dc/calculator'

describe DC::Calculator do
  before :each do
    @output = StringIO.new('', 'w+')
    @input = StringIO.new('', 'r')
    @calc = DC::Calculator.new(@input, @output)
  end

  it "should add two numbers with +" do
    @calc.parse('1 2 +p')
    expect(@output.string).to eq "3\n"
  end

  it "should subtract two numbers with -" do
    @calc.parse('2 1 -p')
    expect(@output.string).to eq "1\n"
  end

  it "should handle negative results from subtraction" do
    @calc.parse('3 5 -p')
    expect(@output.string).to eq "-2\n"
  end

  it "should computer expected values for remainder" do
    # GNU dc documents that % is the same as the sequence Sd dld/ Ld*-.
    a = [4, -4, 2, -2]
    b = [2, -2, 1, -1]
    a.each do |av|
      b.each do |bv|
        @output.string = ''
        numbers = "#{av.to_s.tr('-', '_')} #{bv.to_s.tr('-', '_')}"
        @calc.parse("#{numbers} % #{numbers} Sd dld/ Ld*-pp")
        values = @output.readlines.each { |s| s.chomp! }
        expect(values[0]).to eq values[1]
      end
    end
  end
end
