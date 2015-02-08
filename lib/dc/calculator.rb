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

  class UnbalancedBracketsError < CalculatorError
    def initialize
      @name = :unbalanced
      super("Unbalanced brackets")
    end
  end

  class Calculator
    attr_reader :stack, :registers

    def initialize(input = $stdin, output = $stdout)
      @stack = []
      @registers = []
      256.times { @registers.push [] }
      @input = input
      @output = output
      @string_depth = 0
      @string = nil
    end

    def dispatch(op, arg = nil)
      case
      when [:+, :-, :*, :/, :%].include?(op)
        binop op
      when [:p, :n, :f].include?(op)
        printop(op)
      when op == :d
        @stack.unshift @stack[0]
      when op == :r
        @stack[0], @stack[1] = @stack[1], @stack[0]
      when op == :z
        @stack.unshift @stack.length
      when op == :x
        parse(@stack.shift) if @stack[0].is_a? String
      when [:L, :S, :l, :s].include?(op)
        regop op, arg
      when [:!=, :'=', :>, :'!>', :<, :'!<'].include?(op)
        cmpop op, arg
      end
    end

    def printop(op)
      case op
      when :p
        @output.puts @stack[0].is_a?(String) ? @stack[0] : @stack[0].to_i
      when :n
        val = @stack.shift
        @output.print val.is_a?(String) ? val : val.to_i
      when :f
        @stack.each do |item|
          @output.puts item.is_a?(String) ? item : item.to_i
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

    def parse(line)
      line.force_encoding('BINARY')
      while !line.empty?
        if @string_depth > 0
          line = parse_string(line)
        elsif line.sub!(/^(_)?(\d+(?:\.\d+)?)/, '')
          val = Rational($~[2])
          val = -val if !!$~[1]
          push(val)
        elsif line.sub!(/^\s+/, '')
        elsif line.sub!(/^#[^\n]+/, '')
        elsif line.sub!(%r(^[-+*/%drnpzxf]), '')
          dispatch($~[0].to_sym)
        elsif line.sub!(/^([SsLl])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/^(!?[<>=])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
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
  end
end
