require_relative 'spec_helper'

class FakeNode
  def type
    :nonexistent
  end
end

describe DC::Generator do
  def run(s)
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    calc = DC::Calculator.new(input, output, all: true)
    calc.parse(s)
    calc
  end

  def generate_and_run(s)
    dc = DC::Generator.new(true).emit(s)
    puts dc if ENV['DEBUG']
    run(dc)
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

  it 'should raise when processing an unknown node' do
    dc = DC::Generator.new(true)
    expect do
      dc.send(:process, FakeNode.new)
    end.to raise_exception(DC::UnimplementedNodeError, /unknown node type/i)
  end

  it 'should be able to handle Integer#times' do
    code = <<-EOM
    n = 0
    25.times { |i| n += i + 1 }
    n
    EOM
    generate_and_compare code
  end

  it 'should be able to handle Range#each' do
    code = <<-EOM
    m = 1
    n = 0
    (1..10).each { |i| n -= i; m *= n }
    m - n
    EOM
    generate_and_compare code
  end

  it 'should be able to handle Range#reverse_each' do
    code = <<-EOM
    m = 1
    n = 0
    (1..10).reverse_each { |i| n -= i; m *= n }
    m - n
    EOM
    generate_and_compare code
  end

  it 'should be able to handle if and break statements' do
    code = <<-EOM
    n = 0
    (1..10).each do |i|
      n += i
      break if n > 10
    end
    n
    EOM
    generate_and_compare code
  end

  it 'should be able to handle methods in the math library' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def initialize
          end

          def f(x)
            x * 2
          end
        end
      end
    end
    DC::Math::Library.new.f(3.5)
    EOM
    generate_and_compare code
  end

  it 'should ignore scale methods in the math library' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def scale
            @scale
          end

          def scale=(value)
            @scale = value
          end

          def f(x)
            scale = 2
            x * 2
          end
        end
      end
    end
    DC::Math::Library.new.f(3.5)
    EOM
    generate_and_compare code
  end

  it 'should generate k calls for setting scale' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def scale=(value)
            @scale = value
          end

          def f(x)
            scale = 2
            x * 2
          end
        end
      end
    end
    l = DC::Math::Library.new
    l.f(3.5)
    EOM
    generate_and_compare code
    dc = DC::Generator.new.emit(code)
    expect(dc).to match(/\[.*?2\s*k.*?\]Sf/m)
  end

  it 'should handle loading special variables properly' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def ibase
            10
          end

          def f(x)
            a = ibase
            a + x * 2
          end
        end
      end
    end
    l = DC::Math::Library.new
    l.f(3.5)
    EOM
    generate_and_compare code
  end

  it 'should generate i calls for setting ibase' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def ibase
            @ibase
          end

          def ibase=(value)
            @ibase = value
          end

          def f(x)
            ibase = 10
            ibase * 2 + x
          end
        end
      end
    end
    l = DC::Math::Library.new
    l.f(5)
    EOM
    generate_and_compare code
    dc = DC::Generator.new.emit(code)
    expect(dc).to match(/\[.*?10\s*i.*?\]Sf/m)
  end

  it 'should generate expected results for the length function' do
    values = {
      '1' => 1,
      '0.1' => 1,
      '0.22' => 2,
      '99' => 2,
      '100' => 3,
      '0.0006' => 4,
      '0.00062' => 5,
    }
    values.each do |value, expected|
      dc = DC::Generator.new.emit("s = #{value}; length(s)")
      calc = run(dc)
      expect(calc.stack).to eq [expected]
    end
  end
end
