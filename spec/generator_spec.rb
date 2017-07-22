require_relative 'spec_helper'

describe DC::CodeGenerator::Generator do
  def run(s)
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    options = ENV['DEBUG'] ? { all: true } : {}
    calc = DC::Calculator.new(input, output, options)
    calc.parse(s)
    puts "Messages: \n#{calc.output.string}" if ENV['DEBUG']
    calc
  end

  def generate_and_run(s)
    debug = ENV['DEBUG']
    dc = DC::CodeGenerator::Generator.new(true, debug: debug, ignored_functions:
                                          [:wrap]).emit(s)
    puts "\nCode is: \n#{dc}\n" if debug
    run(dc)
  end

  def generate_and_compare(s)
    calc = generate_and_run(s)
    ruby = eval(s) # rubocop:disable Lint/Eval
    expect(calc.stack).to eq [ruby]
  end

  it 'should generate proper results for small integer arithmetic' do
    (-2..2).each do |x|
      (-2..2).each do |y|
        %i[+ - *].each do |op|
          generate_and_compare "#{x} #{op} #{y}"
        end
      end
    end
  end

  it 'should generate proper results for division' do
    (-10..10).each do |x|
      generate_and_compare "(#{x}.to_r / 3).to_i"
    end
  end

  it 'should generate proper results for integral exponentiation' do
    (-10..10).each do |x|
      (-5..5).each do |y|
        next if x == 0 && y < 0
        generate_and_compare "#{x} ** #{y}"
      end
    end
  end

  it 'should generate proper results for negation' do
    (-2..2).each do |x|
      generate_and_compare "-#{x}"
    end
  end

  it 'should generate proper results for modulus' do
    (-10..10).each do |x|
      generate_and_compare "#{x} % 3"
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
        %i[+ - *].each do |op|
          generate_and_compare "x = #{x}; x #{op}= #{y}"
        end
      end
    end
  end

  it 'should generate proper results for Math.sqrt and integral values' do
    (0..10).each do |x|
      x **= 2
      generate_and_compare "x = #{x}; Math.sqrt(x)"
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
    generate_and_compare 'def e(x); y = x + 1; y; end; e(2)'
    generate_and_compare 'def e(x); x + 1; end; e(2)'
  end

  it 'should call multiple functions correctly' do
    generate_and_compare 'def e(x); y = x + 1; y; end; e(2) + e(3)'
  end

  it 'should raise when function names are too long' do
    expect do
      generate_and_compare 'def foo(x); y = x + 1; y; end; foo(2)'
    end.to raise_exception(DC::InvalidNameError, /single character/)
  end

  it 'should raise when processing an unknown node' do
    dc = DC::CodeGenerator::Generator.new(true)
    fakenode_klass = Class.new do
      def type
        :nonexistent
      end
    end
    expect do
      dc.send(:process, fakenode_klass.new)
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

  it 'should be able to handle 0.times' do
    code = <<-EOM
    n = 0
    0.times { |i| n += i + 1 }
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

  it 'should be able to handle while loops' do
    code = <<-EOM
    i = 0
    n = 0
    while i < 25
      n += i + 1
      i += 1
    end
    n
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

  it 'should be able to handle if statements with code' do
    code = <<-EOM
    scale = 10
    n = 25
    (-2..2).each do |i|
      v = i

      w = 0
      if v < 0
        v = -v
        w = 5
      end
      x = (v * v * v).to_r
      result = 0
      if w == 5
        result = 1 / x
      end
      if w == 0
        result = x / 1
      end
      n += result
    end
    n.truncate(10)
    EOM
    generate_and_compare code
  end

  it 'should be able to handle while loops with breaks' do
    code = <<-EOM
    i = 0
    n = 0
    while i < 50
      n += i + 1
      i += 1
      break if i == 25
    end
    n
    EOM
    generate_and_compare code
  end

  it 'should be able to handle loop blocks' do
    code = <<-EOM
    n = 0
    i = 1
    loop do
      n += i
      i += 1
      break if n > 10
    end
    n
    EOM
    generate_and_compare code
  end

  it 'should be able to handle return statements' do
    code = <<-EOM
    def f(x)
      n = 0
      i = 1
      loop do
        n += i
        i += 1
        return i if n > x
      end
    end
    f(10)
    EOM
    generate_and_compare code
  end

  it 'should be able to handle multiple functions with return statements' do
    code = <<-EOM
    def f(x)
      n = 0
      i = 1
      loop do
        n += i
        i += 1
        return i if n > x
      end
    end
    def g(x)
      n = 5
      return x + 1 if n > x
      return 4
    end
    f(10) + g(0) + g(10)
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

  it 'should ignore ignored functions in the math library' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def wrap
            s * 2
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
    dc = DC::CodeGenerator::Generator.new.emit(code)
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

  it 'should handle preallocation properly' do
    code = <<-EOM
    module DC
      module Math
        class Library
          def ibase
            10
          end

          def f(x)
            while x < 2
              self.scale = 2
              self.scale = 1 if x < 1
            end
            a = ibase
            a + x * 2
          end
        end
      end
    end
    l = DC::Math::Library.new
    l.f(2)
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
    dc = DC::CodeGenerator::Generator.new.emit(code)
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
      dc = DC::CodeGenerator::Generator.new(true).emit("s = #{value};
                                                       length(s)")
      puts "\nCode is: \n#{dc}\n" if ENV['DEBUG']
      calc = run(dc)
      expect(calc.stack).to eq [expected]
    end
  end

  it 'should generate expected results for the scale function' do
    values = {
      '1' => 0,
      '0.1' => 1,
      '0.22' => 2,
      '99' => 0,
      '100' => 0,
      '0.0006' => 4,
      '0.00062' => 5,
    }
    values.each do |value, expected|
      dc = DC::CodeGenerator::Generator.new(true).emit("s = #{value}; scale(s)")
      puts "\nCode is: \n#{dc}\n" if ENV['DEBUG']
      calc = run(dc)
      expect(calc.stack).to eq [expected]
    end
  end

  it 'should generate expected results for if-else conditions' do
    pending
    code = <<-EOM
      def f(x)
        if (x % 2) == 0
          0
        else
          1
        end
      end
      f(3)
    EOM
    generate_and_compare code
  end
end
