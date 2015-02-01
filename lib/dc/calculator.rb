module DC
  class Calculator
    attr_reader :stack, :registers

    def initialize(input = $stdin, output = $stdout)
      @stack = []
      @registers = []
      256.times { @registers.push [] }
      @input = input
      @output = output
    end

    def dispatch(op, arg = nil)
      case
      when [:+, :-, :*, :/, :%].include?(op)
        binop op
      when op == :p
        @output.puts @stack[0].to_i
      when op == :d
        @stack.unshift @stack[0]
      when op == :r
        @stack[0], @stack[1] = @stack[1], @stack[0]
      when op == :z
        @stack.unshift @stack.length
      when [:L, :S, :l, :s].include?(op)
        regop op, arg
      end
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

    def push(val)
      @stack.unshift(val)
    end

    def parse(line)
      line.force_encoding('BINARY')
      while !line.empty?
        if line.sub!(/^(_)?(\d+(?:\.\d+)?)/, '')
          val = Rational($~[2])
          val = -val if !!$~[1]
          push(val)
        elsif line.sub!(/^\s+/, '')
        elsif line.sub!(%r(^[-+*/%drpz]), '')
          dispatch($~[0].to_sym)
        elsif line.sub!(/^([SsLl])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line[0] == 'q'
          raise SystemExit
        else
          fail "trap: invalid command #{line[0]}"
        end
      end
    end
  end
end
