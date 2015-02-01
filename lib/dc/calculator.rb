module DC
  class Calculator
    def initialize
      @stack = []
    end

    def dispatch(op)
      case
      when [:+, :-, :*, :/, :%].include?(op)
        binop op
      when op == :p
        puts @stack[-1].to_i
      end
    end

    def binop(op)
      top = @stack.pop
      second = @stack.pop
      @stack.push(top.send(op, second))
    end

    def push(val)
      @stack.push(val)
    end

    def parse(line)
      while !line.empty?
        if line.sub!(/^(_)?(\d+(?:\.\d+)?)/, '')
          val = Rational($~[2])
          val = -val if !!$~[1]
          push(val)
        elsif line.sub!(/^\s+/, '')
        elsif line.sub!(%r([-+*/%p]), '')
          dispatch($~[0].to_sym)
        elsif line[0] == 'q'
          raise SystemExit
        else
          fail "trap: invalid command #{line[0]}"
        end
      end
    end
  end
end
