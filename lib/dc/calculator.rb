require 'set'

require 'dc/exception'
require 'dc/math'
require 'dc/util'

module DC
  class CalculatorError < DC::Exception
    attr_reader :name
  end

  class InvalidCommandError < CalculatorError
    attr_reader :command

    def initialize(command)
      @name = :command
      if command.is_a? Symbol
        @command = command
        super("Invalid command '#{command}'")
      else
        super(command)
      end
    end
  end

  class UnsupportedExtensionError < InvalidCommandError
    attr_reader :command, :standard

    def initialize(command, standard)
      super("Unsupported extension '#{command}': standards #{standard} not enabled")
      @name = :extension
      @command = command
      @standard = standard
    end
  end

  class UnbalancedBracketsError < CalculatorError
    def initialize
      @name = :unbalanced
      super("Unbalanced brackets")
    end
  end

  class InternalCalculatorError < CalculatorError
  end

  class InsecureCommandError < CalculatorError
  end

  class Scale
    attr_accessor :value

    def initialize(val)
      @value = val.to_i
    end

    def <=>(other)
      @value <=> other.to_r
    end

    def to_i
      @value.to_i
    end

    def to_f
      @value.to_f
    end

    def to_r
      @value.to_r
    end
  end

  class Numeric
    include Comparable

    attr_accessor :value, :scale

    def initialize(value, scale, calc_scale)
      @value = Rational(value)
      @scale = scale.to_i
      @k = calc_scale
    end

    def -@
      Numeric.new(-@value, @scale, @k)
    end

    def +(other)
      other = Numeric.new(other, k, @k) unless other.is_a? Numeric
      Numeric.new(@value + other.value, [@scale, other.scale].max, @k)
    end

    def -(other)
      other = Numeric.new(other, k, @k) unless other.is_a? Numeric
      Numeric.new(@value - other.value, [@scale, other.scale].max, @k)
    end

    def *(other)
      other = Numeric.new(other, k, @k) unless other.is_a? Numeric
      scale = [@scale + other.scale, [@scale, other.scale, k].max].min
      v = (@value * other.value).truncate(scale)
      Numeric.new(v, scale, @k)
    end

    def /(other)
      other = Numeric.new(other, k, @k) unless other.is_a? Numeric
      v = (@value / other.value).truncate(@k.to_i)
      Numeric.new(v, k, @k)
    end

    def %(other)
      other = Numeric.new(other, k, @k) unless other.is_a? Numeric
      v = (@value % other.value).truncate(k)
      Numeric.new(v, k, @k)
    end

    def **(other)
      other = Numeric.new(other, k, @k) unless other.is_a? Numeric
      Numeric.new(@value ** other.value, k, @k)
    end

    def respond_to?(symbol)
      super(symbol) || @value.respond_to?(symbol)
    end

    def method_missing(symbol, *args)
      @value.send(symbol, *args)
    end

    def <=>(other)
      return @value <=> other unless other.is_a? Numeric
      @value <=> other.value
    end

    def to_r
      @value
    end

    def to_i
      @value.to_i
    end

    def to_f
      @value.to_f
    end

    def to_s(base=10)
      DC::Util.stringify(@value, @scale, base)
    end

    # Number of digits.
    def length
      DC::Util.length(@value, @scale)
    end

    protected

    def k
      @k.to_i
    end
  end

  class Calculator
    attr_reader :stack, :registers, :input, :output
    attr_accessor :ibase, :obase

    def initialize(input = $stdin, output = $stdout, options = {})
      @stack = []
      @registers = Hash.new { |hash, key| hash[key] = [] }
      @arrays = Hash.new { |hash, key| hash[key] = [] }
      @input = input
      @output = output
      @string_depth = 0
      @string = nil
      @ibase = @obase = 10
      @scale = Scale.new 0
      @extensions = Set.new
      @stack_level = 0
      @break = true
      [:gnu, :freebsd].each do |ext|
        @extensions.add ext if options[ext] || options[:all]
      end
      @extensions.add :insecure if options[:insecure]
    end

    def scale
      @scale.to_r
    end

    def scale=(x)
      @scale.value = x.to_i
    end

    def arrays
      @arrays.map { |k, v| [k, v[0]] }.to_h
    end

    def extension?(option)
      option = [option] unless option.is_a? Enumerable
      s = Set.new option
      @extensions.intersect? s
    end

    def extensions
      @extensions.sort
    end

    def push(val)
      fail InternalCalculatorError, 'Trying to push invalid value' if val.nil?
      fail InternalCalculatorError, 'Trying to push Fixnum' if val.is_a? Fixnum
      @stack.unshift(val)
    end

    def pop
      fail InternalCalculatorError, 'Trying to pop empty stack' if @stack.empty?
      @stack.shift
    end

    def parse(line)
      !!do_parse(line.dup)
    end

    def secure?
      !@extensions.include? :insecure
    end

    protected

    def do_parse(line)
      line = line.dup
      line.force_encoding('BINARY')
      until line.empty? || @unwind
        if @string
          line = parse_string(line)
        elsif line.sub!(/\A(_)?([\dA-F]+(?:\.([\dA-F]+))?)/, '')
          push(number($~[2], $~[1]))
        elsif line.sub!(/\A(_)?(\.([\dA-F]+))/, '')
          push(number($~[2], $~[1]))
        elsif line.sub!(/\A\s+/, '')
        elsif line.sub!(/\A#[^\n]+/, '')
        elsif line.sub!(%r(\A[-+*/%^|~dpPzZXfiIoOkKvc]), '')
          dispatch($~[0].to_sym)
        elsif line.sub!(/\Ax/, '')
          @stack_level += 1
          resp = dispatch($~[0].to_sym)
          @stack_level -= 1
          return @break ? nil : resp if !resp.nil? && resp <= @stack_level
          @unwind = false
        elsif line.sub!(/\A([SsLl:;])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/\A(!?[<>=])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/\A([nra])/, '')
          dispatch_extension($~[0].to_sym, [:gnu, :freebsd])
        elsif line.sub!(/\A([NRG({])/, '')
          dispatch_extension($~[0].to_sym, [:freebsd])
        elsif line.sub!(/\A\?/, '')
          do_parse(@input.gets)
        elsif line.sub!(/\A(!)([^\n]+)/, '')
          dispatch_insecure($~[1].to_sym, $~[2])
        elsif line.start_with? '['
          line = parse_string(line)
        elsif line.start_with? ']'
          fail UnbalancedBracketsError
        elsif line[0] == 'q'
          return if @stack_level == 0
          @unwind = true
          return @stack_level - 1
        elsif line[0] == 'Q'
          level = pop.to_i
          @break = false
          @unwind = true
          return 1 if level > @stack_level
          return @stack_level - level + 1
        else
          fail InvalidCommandError, line[0].to_sym
        end
      end
      @stack_level
    end

    def number(s, negative=false)
      int, frac = s.split('.')
      value = integer(int)
      frac_digits = frac.to_s.length
      value += Rational(integer(frac), @ibase ** frac_digits) if frac
      # For ease of internal conversion and compatibility with the GNU
      # implementation, the scale is always computed in base 10.  Also for GNU
      # compatibility, we always compute the number of fractional digits as the
      # number entered.
      val = Numeric.new(value, frac_digits, @scale)
      negative ? -val : val
    end

    # dc has an odd way of parsing integers. It allows input using any
    # characters that are valid in hexadecimal, but maintains place value using
    # the input base.  Thus in base 16, FE is 254; in base 12, it's 194
    # (15 * 12 + 14); and in base 10, it's 164 (15 * 10 + 14).  Yes, this is
    # bizarre, but people rely on being able to say Ai to reset the input base
    # to 10 regardless of its current state.
    def integer(s)
      value = 0
      s.each_char do |c|
        value *= @ibase
        value += c.to_i(16)
      end
      value
    end

    def mathop(op)
      case op
      when :|
        mod = pop.to_r
        exp = pop.to_i
        base = pop.to_i
        push DC::Numeric.new(DC::Math.modexp(base, exp, mod), 0, @scale)
      when :~
        denom = pop
        num = pop
        push num / denom
        push num % denom
      end
    end

    def int(x)
      Numeric.new(x, 0, @scale)
    end

    def baseop(op)
      if [:i, :o, :k].include? op
        methods = { i: :ibase=, o: :obase=, k: :scale= }
        method(methods[op]).call(pop.to_i)
      else
        ops = { I: @ibase, O: @obase, K: @scale.to_r }
        push int(ops[op])
      end
    end

    def dispatch(op, arg = nil)
      case
      when [:+, :-, :*, :/, :%, :^].include?(op)
        binop op
      when [:P, :p, :n, :f].include?(op)
        printop(op)
      when [:|, :~].include?(op)
        mathop op
      when [:I, :O, :K, :i, :o, :k].include?(op)
        baseop op
      when op == :d
        push @stack[0]
      when op == :c
        @stack.clear
      when op == :r
        a = pop
        b = pop
        push a
        push b
      when op == :z
        push Numeric.new(@stack.length, 0, @scale)
      when op == :Z
        push int(pop.length)
      when op == :x
        do_parse(pop) if @stack[0].is_a? String
      when op == :X
        top = pop
        push(int(top.is_a?(String) ? 0 : top.scale))
      when op == :a
        stringify
      when op == :v
        result = DC::Math.root(pop, 2, @scale)
        push(Numeric.new(result, @scale.to_i, @scale))
      when op == :N
        push(Numeric.new(pop == 0 ? 1 : 0, 0, @scale))
      when op == :R
        pop
      when [:L, :S, :l, :s].include?(op)
        regop op, arg
      when [:!=, :'=', :>, :'!>', :<, :'!<'].include?(op)
        cmpop op, arg
      when [:G, :'(', :'{'].include?(op)
        extcmpop op
      when [:';', :':'].include?(op)
        arrayop op, arg
      end
    end


    def dispatch_insecure(op, arg)
      fail InsecureCommandError, op if secure?
      case op
      when :!
        system(arg)
      end
    end

    def dispatch_extension(op, exts)
      fail UnsupportedExtensionError.new(op, exts) unless extension? exts
      dispatch(op)
    end

    def convert_string(s)
      # FreeBSD uses C-style strings (boo!)
      s == "\x00" && extension?(:freebsd) && !extension?(:gnu) ? '' : s
    end

    def arrayop(op, reg)
      @arrays[reg][0] ||= []
      index = pop
      case op
      when :':'
        value = pop
        @arrays[reg][0][index] = value
      when :';'
        push(@arrays[reg][0][index] || int(0))
      end
    end

    def stringify
      val = pop
      if val.is_a? String
        val = val.empty? ? '' : val[0]
      else
        val = convert_string((val.to_i % 256).chr)
      end
      push(val)
    end

    def printable(val)
      val.is_a?(DC::Numeric) ? val.to_s(@obase).upcase : val
    end

    def printop(op)
      case op
      when :p
        @output.puts printable(@stack[0])
      when :P
        val = pop
        if val.is_a? DC::Numeric
          val = val.to_i.to_s(16)
          val = "0#{val}" if val.length.odd?
          val = [val].pack('H*')
        end
        @output.print val
      when :n
        val = pop
        @output.print printable(val)
      when :f
        @stack.each do |item|
          @output.puts printable(item)
        end
      end
    end

    def cmpop(op, reg)
      syms = { :'=' => :==, :'!>' => :<=, :'!<' => :>= }
      op = syms[op] || op
      top = pop
      second = pop
      return unless top.send(op, second)
      do_parse(@registers[reg][0])
    end

    def extcmpop(op)
      syms = { :G => :==, :"(" => :<, :"{" => :<= }
      op = syms[op]
      top = pop
      second = pop
      push(Numeric.new(top.send(op, second) ? 1 : 0, 0, @scale))
    end

    def regop(op, reg)
      case op
      when :L
        push @registers[reg].shift
        @arrays[reg].shift
      when :S
        @registers[reg].unshift pop
        @arrays[reg].unshift []
      when :l
        push @registers[reg][0]
      when :s
        @registers[reg][0] = pop
      end
    end

    def binop(op)
      map = {:^ => :**}
      op = map[op] || op
      top = pop
      second = pop
      push(second.send(op, top))
    end

    def parse_string(s)
      offset = 0
      @string ||= ''
      unless s[/[\[\]]/]
        @string << s
        return ''
      end
      s.scan(/([^\[\]]*)([\[\]])([^\[\]]+\z)?/) do |code, delim, trail|
        @string_depth += (delim == ']' ? -1 : 1)
        offset += code.length + delim.length
        if @string_depth == 0
          push(@string[1..-1] + code)
          @string = nil
          return s[offset..-1]
        end
        @string << code << delim << trail.to_s
      end
      ''
    end
  end
end
