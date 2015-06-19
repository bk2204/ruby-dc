require 'set'

module DC
  class CalculatorError < StandardError
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
    def initialize(val)
      @value = val.to_i
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
      @scale = scale
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
      other = Numeric.new(other, k, k) unless other.is_a? Numeric
      v = (@value / other.value).truncate(k)
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
      base = base.to_i
      i = @value.to_i
      temp = @value.to_r.truncate(@scale)
      frac = temp - i
      s = i.to_s(base)
      s << '.' if @scale > 0
      @scale.times do |j|
        frac *= base
        value = frac.to_i
        frac -= value
        s << value.to_s(base)
      end
      s
    end

    # Number of digits.
    def length
      to_s.sub(/^0\./, '.').gsub('.', '').length
    end

    protected
    def k
      @k.to_i
    end
  end

  class Calculator
    attr_reader :stack, :registers

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
      line.force_encoding('BINARY')
      while !line.empty?
        if @string
          line = parse_string(line)
        elsif line.sub!(/\A(_)?([\dA-F]+(?:\.([\dA-F]+))?)/, '')
          push(number($~[2], $~[1]))
        elsif line.sub!(/\A(_)?(\.([\dA-F]+))/, '')
          push(number($~[2], $~[1]))
        elsif line.sub!(/\A\s+/, '')
        elsif line.sub!(/\A#[^\n]+/, '')
        elsif line.sub!(%r(\A[-+*/%^|~dpzZXfiIoOkKvc]), '')
          dispatch($~[0].to_sym)
        elsif line.sub!(/\Ax/, '')
          @stack_level += 1
          resp = dispatch($~[0].to_sym)
          @stack_level -= 1
          return resp if !resp.nil? && resp < @stack_level && !@break
          return if resp == @stack_level && @break
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
          raise UnbalancedBracketsError
        elsif line[0] == 'q'
          return if @stack_level == 0
          return @stack_level - 1
        elsif line[0] == 'Q'
          level = pop.to_i
          @break = false
          return 0 if level > @stack_level
          return @stack_level - level
        else
          raise InvalidCommandError, line[0].to_sym
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
      s.each_char { |c|
        value *= @ibase
        value += c.to_i(16)
      }
      value
    end

    def dispatch(op, arg = nil)
      case
      when [:+, :-, :*, :/, :%, :^].include?(op)
        binop op
      when [:p, :n, :f].include?(op)
        printop(op)
      when op == :|
        mod = pop.to_r
        exp = pop.to_i
        base = pop.to_i
        push DC::Numeric.new(DC::Math.modexp(base, exp, mod), 0, @scale)
      when op == :~
        denom = pop
        num = pop
        push num / denom
        push num % denom
      when op == :I
        push Numeric.new(@ibase, 0, @scale)
      when op == :O
        push Numeric.new(@obase, 0, @scale)
      when op == :K
        push Numeric.new(@scale.to_r, 0, @scale)
      when op == :i
        @ibase = pop.to_i
      when op == :o
        @obase = pop.to_i
      when op == :k
        @scale = pop.to_i
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
        push pop.length
      when op == :x
        do_parse(pop) if @stack[0].is_a? String
      when op == :X
        top = pop
        push(top.is_a?(String) ? 0 : top.scale)
      when op == :a
        stringify
      when op == :v
        result = DC::Math.root(pop, 2, @scale)
        push(Numeric.new(result, @scale, @scale))
      when op == :N
        push(Numeric.new(pop == 0 ? 1 : 0, 0, @scale))
      when op == :R
        pop
      when [:L, :S, :l, :s].include?(op)
        regop op, arg
      when [:!=, :'=', :>, :'!>', :<, :'!<'].include?(op)
        cmpop op, arg
      when [:G, :'(', :'{'].include?(op)
        extcmpop op, arg
      when [:';', :':'].include?(op)
        arrayop op, arg
      end
    end


    def dispatch_insecure(op, arg)
      raise InsecureCommandError, op if secure?
      case op
      when :!
        system(arg)
      end
    end

    def dispatch_extension(op, exts)
      raise UnsupportedExtensionError.new(op, exts) unless extension? exts
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
        push(@arrays[reg][0][index] || 0)
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
      return unless second.send(op, top)
      do_parse(@registers[reg][0])
    end

    def extcmpop(op, reg)
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
      if !s[/[\[\]]/]
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
      return ''
    end
  end
end
