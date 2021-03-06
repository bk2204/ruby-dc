require 'set'

require 'dc/exception'
require 'dc/math'
require 'dc/util'

module DC
  # A generic dc error.
  class CalculatorError < DC::Exception
    attr_reader :name
  end

  # An exception representing an unknown or invalid command.
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

  # An exception representing an extension that has not been enabled.
  class UnsupportedExtensionError < InvalidCommandError
    attr_reader :command, :standard

    def initialize(command, standard)
      super("Unsupported extension '#{command}': " \
            "standards #{standard} not enabled")
      @name = :extension
      @command = command
      @standard = standard
    end
  end

  # An exception occurring when square brackets are mismatched.
  class UnbalancedBracketsError < CalculatorError
    def initialize
      @name = :unbalanced
      super('Unbalanced brackets')
    end
  end

  # An internal error.
  class InternalCalculatorError < CalculatorError
  end

  # An error when attempting to run a shell command in secure mode.
  class InsecureCommandError < CalculatorError
  end

  # An object representing the precision of the calculator.
  #
  # The value of this object is the number of decimal digits after the decimal
  # point.
  #
  # This is essentially a glorified integer wrapped in a class.  DC uses a
  # global scale value in some math operations, which means that it must be an
  # object to be shared across multiple objects and kept in sync.
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

  # A rational number in a dc calculator.
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
      other = numericize(other)
      Numeric.new(@value + other.value, [@scale, other.scale].max, @k)
    end

    def -(other)
      other = numericize(other)
      Numeric.new(@value - other.value, [@scale, other.scale].max, @k)
    end

    def *(other)
      other = numericize(other)
      scale = [@scale + other.scale, [@scale, other.scale, k].max].min
      v = (@value * other.value).truncate(scale)
      Numeric.new(v, scale, @k)
    end

    def /(other)
      other = numericize(other)
      v = (@value / other.value).truncate(@k.to_i)
      Numeric.new(v, k, @k)
    end

    def %(other)
      other = numericize(other)
      v = (@value % other.value).truncate(k)
      Numeric.new(v, k, @k)
    end

    def **(other)
      other = numericize(other)
      Numeric.new(@value**other.value, k, @k)
    end

    def respond_to_missing?(symbol, *args)
      super(symbol, *args) || @value.respond_to?(symbol, *args)
    end

    def method_missing(symbol, *args)
      if @value.respond_to?(symbol)
        @value.send(symbol, *args)
      else
        super
      end
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

    def to_s(base = 10)
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

    def numericize(other)
      return other if other.is_a? Numeric
      Numeric.new(other, k, @k)
    end
  end

  # A calculator implementing the dc language.
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
      %i[gnu freebsd].each do |ext|
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

    def push(*args)
      args.each do |val|
        if val.nil?
          raise InternalCalculatorError, 'Trying to push invalid value'
        end
        if val.is_a? Integer
          raise InternalCalculatorError, 'Trying to push Integer'
        end
      end
      @stack.unshift(*args)
    end

    def pop(*args)
      count = args.empty? ? 1 : args[0]
      if @stack.length < count
        raise InternalCalculatorError, 'Trying to pop empty stack'
      end
      @stack.shift(*args)
    end

    def parse(line)
      do_parse(line) ? true : false
    end

    def secure?
      !@extensions.include? :insecure
    end

    protected

    DISPATCH = {
      :';' => lambda do |reg|
        @arrays[reg][0] ||= []
        push(@arrays[reg][0][pop] || int(0))
      end,
      :':' => lambda do |reg|
        @arrays[reg][0] ||= []
        index, value = pop(2)
        @arrays[reg][0][index] = value
      end,
      :| => lambda do
        mod = pop.to_r
        exp, base = pop(2).map(&:to_i)
        push DC::Numeric.new(DC::Math.modexp(base, exp, mod), 0, @scale)
      end,
      :~ => lambda do
        denom, num = pop(2)
        push num / denom
        push num % denom
      end,
      :p => -> { @output.puts printable(@stack[0]) },
      :P => lambda do
        val = pop
        val = num_to_bytes(val) if val.is_a? DC::Numeric
        @output.print val
      end,
      :n => -> { @output.print printable(pop) },
      :f => -> { @stack.each { |item| @output.puts printable(item) } },
      :+ => -> { binop(:+) },
      :- => -> { binop(:-) },
      :* => -> { binop(:*) },
      :/ => -> { binop(:/) },
      :% => -> { binop(:%) },
      :^ => -> { binop(:**) },
      :I => -> { push(int(@ibase)) },
      :O => -> { push(int(@obase)) },
      :K => -> { push(int(@scale.to_r)) },
      :a => -> { stringify },
      :v => lambda do
        push(Numeric.new(DC::Math.root(pop, 2, @scale), @scale.to_i, @scale))
      end,
      :N => -> { push(int(pop == 0 ? 1 : 0)) },
      :!= =>   ->(reg) { cmpop(:!=, reg) },
      :'=' =>  ->(reg) { cmpop(:==, reg) },
      :> =>    ->(reg) { cmpop(:>, reg) },
      :'!>' => ->(reg) { cmpop(:<=, reg) },
      :< =>    ->(reg) { cmpop(:<, reg) },
      :'!<' => ->(reg) { cmpop(:>=, reg) },
      :G =>   -> { extcmpop(:==) },
      :'(' => -> { extcmpop(:<) },
      :'{' => -> { extcmpop(:<=) },
      :i => -> { base_setop(:ibase=) },
      :o => -> { base_setop(:obase=) },
      :k => -> { base_setop(:scale=) },
      :S => lambda do |reg|
        @registers[reg].unshift pop
        @arrays[reg].unshift []
      end,
      :L => lambda do |reg|
        push @registers[reg].shift
        @arrays[reg].shift
      end,
      :s => ->(reg) { @registers[reg][0] = pop },
      :l => ->(reg) { push @registers[reg][0] },
      :z => -> { push int(@stack.length) },
      :Z => -> { push int(pop.length) },
      :X => lambda do
        top = pop
        push(int(top.is_a?(String) ? 0 : top.scale))
      end,
      :x => -> { do_parse(pop) if @stack[0].is_a? String },
      :d => -> { push @stack[0] },
      :c => -> { @stack.clear },
      :r => lambda do
        a, b = pop(2)
        push b, a
      end,
      :R => -> { pop },
    }.freeze

    def do_parse(line)
      line = line.dup
      line.force_encoding('BINARY')
      until line.empty? || @unwind
        ret = do_parse_one(line)
        return ret unless ret == :next
      end
      @stack_level
    end

    def do_parse_one(line)
      if @string
        line.replace(parse_string(line))
      elsif line.sub!(/\A(_)?([\dA-F]+(?:\.([\dA-F]+))?)/, '')
        push(number($~[2], $~[1]))
      elsif line.sub!(/\A(_)?(\.([\dA-F]+))/, '')
        push(number($~[2], $~[1]))
      elsif line.sub!(/\A\s+/, '')
      elsif line.sub!(/\A#[^\n]+/, '')
      elsif line.sub!(%r{\A[-+*/%^|~dpPzZXfiIoOkKvc]}, '')
        dispatch($~[0].to_sym)
      elsif line.sub!(/\Ax/, '')
        @stack_level += 1
        resp = dispatch($~[0].to_sym)
        @stack_level -= 1
        return @break ? nil : resp if resp && resp <= @stack_level
        @unwind = false
      elsif line.sub!(/\A([SsLl:;])(.)/, '')
        dispatch($~[1].to_sym, $~[2].ord)
      elsif line.sub!(/\A(!?[<>=])(.)/, '')
        dispatch($~[1].to_sym, $~[2].ord)
      elsif line.sub!(/\A([nra])/, '')
        dispatch_extension($~[0].to_sym, %i[gnu freebsd])
      elsif line.sub!(/\A([NRG({])/, '')
        dispatch_extension($~[0].to_sym, [:freebsd])
      elsif line.sub!(/\A\?/, '')
        do_parse(@input.gets)
      elsif line.sub!(/\A(!)([^\n]+)/, '')
        dispatch_insecure($~[1].to_sym, $~[2])
      elsif line.start_with? '['
        line.replace(parse_string(line))
      elsif line.start_with? ']'
        raise UnbalancedBracketsError
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
        raise InvalidCommandError, line[0].to_sym
      end
      :next
    end

    def number(s, negative = false)
      int, frac = s.split('.')
      value = integer(int)
      frac_digits = frac.to_s.length
      value += Rational(integer(frac), @ibase**frac_digits) if frac
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

    def int(x)
      Numeric.new(x, 0, @scale)
    end

    def base_setop(sym)
      method(sym).call(pop.to_i)
    end

    def dispatch(op, *args)
      func = DISPATCH[op]
      instance_exec(*args, &func)
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

    def stringify
      val = pop
      val = if val.is_a? String
              val.empty? ? '' : val[0]
            else
              convert_string((val.to_i % 256).chr)
            end
      push(val)
    end

    def printable(val)
      val.is_a?(DC::Numeric) ? val.to_s(@obase).upcase : val
    end

    # Take a number and convert it to a series of bytes.
    def num_to_bytes(val)
      val = val.to_i.to_s(16)
      val = "0#{val}" if val.length.odd?
      [val].pack('H*')
    end

    def cmpop(op, reg)
      top, second = pop(2)
      return unless top.send(op, second)
      do_parse(@registers[reg][0])
    end

    def extcmpop(op)
      top, second = pop(2)
      push(int(top.send(op, second) ? 1 : 0))
    end

    def binop(op)
      top, second = pop(2)
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
