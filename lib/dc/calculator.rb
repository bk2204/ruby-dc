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

  class Calculator
    attr_reader :stack, :registers

    def initialize(input = $stdin, output = $stdout, options = {})
      @stack = []
      @registers = Hash.new { |hash, key| hash[key] = [] }
      @input = input
      @output = output
      @string_depth = 0
      @string = nil
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
      @extensions.keys.sort
    end

    def push(val)
      @stack.unshift(val)
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
        elsif line.sub!(%r(^[-+*/%dpzxf]), '')
          dispatch($~[0].to_sym)
        elsif line.sub!(/^([SsLl])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/^(!?[<>=])(.)/, '')
          dispatch($~[1].to_sym, $~[2].ord)
        elsif line.sub!(/^([nra])/, '')
          dispatch_extension($~[0].to_sym, [:gnu, :freebsd])
        elsif line.sub!(/^([R])/, '')
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
      when op == :a
        stringify
      when op == :R
        @stack.shift
      when [:L, :S, :l, :s].include?(op)
        regop op, arg
      when [:!=, :'=', :>, :'!>', :<, :'!<'].include?(op)
        cmpop op, arg
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
