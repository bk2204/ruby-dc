require 'set'

module DC
  class CalculatorError < StandardError
    attr_reader :name
  end

  class InvalidCommandError < CalculatorError
    attr_reader :command

    def initialize(command)
      @name = :command
      @command = command
      super("Invalid command '#{command}'")
    end
  end

  class UnsupportedExtensionError < CalculatorError
    attr_reader :command, :standard

    def initialize(command, standard)
      @name = :extension
      @command = command
      @standard = standard
      super("Unsupported extension '#{command}': standards #{standard} not enabled")
    end
  end

  class UnbalancedBracketsError < CalculatorError
    def initialize
      @name = :unbalanced
      super("Unbalanced brackets")
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
      other = Numeric.new(other, @k, @k) unless other.is_a? Numeric
      Numeric.new(@value + other.value, [@scale, other.scale].max, @k)
    end

    def -(other)
      other = Numeric.new(other, @k, @k) unless other.is_a? Numeric
      Numeric.new(@value - other.value, [@scale, other.scale].max, @k)
    end

    def *(other)
      other = Numeric.new(other, @k, @k) unless other.is_a? Numeric
      scale = [@scale + other.scale, [@scale, other.scale, @k].max].min
      v = (@value * other.value).truncate(scale)
      Numeric.new(v, scale, @k)
    end

    def /(other)
      other = Numeric.new(other, @k, @k) unless other.is_a? Numeric
      v = (@value / other.value).truncate(@k)
      Numeric.new(v, @k, @k)
    end

    def %(other)
      other = Numeric.new(other, @k, @k) unless other.is_a? Numeric
      v = (@value % other.value).truncate(@k)
      Numeric.new(v, @k, @k)
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

    def to_s
      format("%.#{@scale}f", @value)
    end
  end

  class Calculator
    attr_reader :stack, :registers

    def initialize(input = $stdin, output = $stdout, options = {})
      @stack = []
      @registers = Hash.new { |hash, key| hash[key] = [] }
      @input = input
      @output = output
      @string_depth = 0
      @string = nil
      @ibase = @obase = 10
      @scale = 0
      @extensions = Set.new
      [:gnu, :freebsd].each do |ext|
        @extensions.add ext if options[ext] || options[:all]
      end
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
      @stack.unshift(val)
    end

    def parse(line)
      line.force_encoding('BINARY')
      while !line.empty?
        if @string_depth > 0
          line = parse_string(line)
        elsif line.sub!(/^(_)?([\dA-F]+(?:\.([\dA-F]+))?)/, '')
          push(number($~[2], $~[1]))
        elsif line.sub!(/^(_)?(\.([\dA-F]+))/, '')
          push(number($~[2], $~[1]))
        elsif line.sub!(/^\s+/, '')
        elsif line.sub!(/^#[^\n]+/, '')
        elsif line.sub!(%r(^[-+*/%dpzXxfiIOkK]), '')
          dispatch($~[0].to_sym)
        elsif line.sub!(/^([SsLl])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/^(!?[<>=])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/^([nra])/, '')
          dispatch_extension($~[0].to_sym, [:gnu, :freebsd])
        elsif line.sub!(/^([NRG({])/, '')
          dispatch_extension($~[0].to_sym, [:freebsd])
        elsif line.start_with? '['
          line = parse_string(line)
        elsif line.start_with? ']'
          raise UnbalancedBracketsError
        elsif line[0] == 'q'
          raise SystemExit
        else
          raise InvalidCommandError, line[0]
        end
      end
    end

    protected

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
      when [:+, :-, :*, :/, :%].include?(op)
        binop op
      when [:p, :n, :f].include?(op)
        printop(op)
      when op == :I
        @stack.unshift Numeric.new(@ibase, 0, @scale)
      when op == :O
        @stack.unshift Numeric.new(@obase, 0, @scale)
      when op == :K
        @stack.unshift Numeric.new(@scale, 0, @scale)
      when op == :i
        @ibase = @stack.shift.to_i
      when op == :k
        @scale = @stack.shift.to_i
      when op == :d
        @stack.unshift @stack[0]
      when op == :r
        @stack[0], @stack[1] = @stack[1], @stack[0]
      when op == :z
        @stack.unshift Numeric.new(@stack.length, 0, @scale)
      when op == :x
        parse(@stack.shift) if @stack[0].is_a? String
      when op == :X
        top = @stack.shift
        @stack.unshift(top.is_a?(String) ? 0 : top.scale)
      when op == :a
        stringify
      when op == :N
        @stack.unshift(Numeric.new(@stack.shift == 0 ? 1 : 0, 0, @scale))
      when op == :R
        @stack.shift
      when [:L, :S, :l, :s].include?(op)
        regop op, arg
      when [:!=, :'=', :>, :'!>', :<, :'!<'].include?(op)
        cmpop op, arg
      when [:G, :'(', :'{'].include?(op)
        extcmpop op, arg
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
      val = @stack.shift
      if val.is_a? String
        val = val.empty? ? '' : val[0]
      else
        val = convert_string((val.to_i % 256).chr)
      end
      push(val)
    end

    def printop(op)
      case op
      when :p
        @output.puts @stack[0]
      when :n
        val = @stack.shift
        @output.print val
      when :f
        @stack.each do |item|
          @output.puts item
        end
      end
    end

    def cmpop(op, reg)
      syms = { :'=' => :==, :'!>' => :<=, :'!<' => :>= }
      op = syms[op] || op
      top = @stack.shift
      second = @stack.shift
      return unless second.send(op, top)
      parse(@registers[reg][0])
    end

    def extcmpop(op, reg)
      syms = { :G => :==, :"(" => :<, :"{" => :<= }
      op = syms[op]
      top = @stack.shift
      second = @stack.shift
      push(Numeric.new(top.send(op, second) ? 1 : 0, 0, @scale))
    end

    def regop(op, reg)
      case op
      when :L
        @stack.unshift @registers[reg].shift
      when :S
        @registers[reg].unshift @stack.shift
      when :l
        @stack.unshift @registers[reg][0]
      when :s
        @registers[reg][0] = @stack.shift
      end
    end

    def binop(op)
      top = @stack.shift
      second = @stack.shift
      @stack.unshift(second.send(op, top))
    end

    def parse_string(s)
      offset = 0
      @string ||= ''
      s.scan(/([^\[\]]*)([\[\]])/) do |code, delim|
        @string_depth += (delim == ']' ? -1 : 1)
        offset += code.length + delim.length
        if @string_depth == 0
          push(@string[1..-1] + code)
          @string = nil
          return s[offset..-1]
        end
        @string << code << delim
      end
      return ''
    end
  end
end
