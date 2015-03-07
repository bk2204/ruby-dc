require_relative 'spec_helper'

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

  it 'should compute addition with the correct precision' do
    @calc.parse('2.3 5.12+')
    expect(@calc.stack).to eq [7.42]
  end

  it 'should compute subtraction with the correct precision' do
    @calc.parse('2.3 5.12-')
    expect(@calc.stack).to eq [-2.82]
  end

  it 'should compute multiplication with the correct precision' do
    @calc.parse('2.3 5.12* 4k 2.3 5.12*f')
    expect(@calc.stack).to eq [11.776, 11.77]
    expect(@output.string).to eq "11.776\n11.77\n"
  end

  it 'should compute division with the correct precision' do
    @calc.parse('3 2/ 1k 3 2/')
    expect(@calc.stack).to eq [1.5, 1]
  end

  it 'should parse terms starting with a leading dot' do
    @calc.parse('.65 .25+')
    expect(@calc.stack).to eq [0.9]
  end

  it 'should always parse hex values regardless of the base' do
    @calc.parse('F 1+i FE Ci FE Ai FE')
    expect(@calc.stack).to eq [164, 194, 254]
  end

  it 'should always parse hex values in fractions regardless of the base' do
    # We use 1* here because we internally hold more precision until a
    # multiplication, division, remainder, or output forces us to convert it.
    @calc.parse('F 1+i .FE 1* Ci .FE 1* Ai .FE 1*f')
    expect(@calc.stack).to eq [1.64, 1.34, 0.99]
    expect(@output.string).to eq "1.64\n1.34\n0.99\n"
  end
end
