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
        expect(@calc.stack[0]).to eq @calc.stack[1]
        values = @output.readlines.each { |s| s.chomp! }
        expect(values[0]).to eq values[1]
      end
    end
  end

  it 'should compute multiplication with the correct precision' do
    @calc.parse('2.3 5.12* 4k 2.3 5.12*')
    expect(@calc.stack).to eq [11.776, 11.77]
  end

  it 'should compute division with the correct precision' do
    @calc.parse('3 2/ 1k 3 2/')
    expect(@calc.stack).to eq [1.5, 1]
  end
end
