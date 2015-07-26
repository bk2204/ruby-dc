require 'parser/current'

require 'dc/exception'

module DC
  class GeneratorError < DC::Exception
  end

  class UnimplementedNodeError < GeneratorError
  end

  class InvalidNameError < GeneratorError
  end

  # A class to generate dc code from Ruby.
  #
  # This class is intentionally designed to be very stupid.  It will never learn
  # about more types than Float, Integer, and Rational.  It has only the most
  # rudimentary knowledge about Ruby.  It is designed simply to make it easier
  # to write and test implementations of the math library, and hopefully to aid
  # others in developing additional useful functions.
  class Generator
    def initialize
      @anonymous_reg = 0
      @registers = {}
    end

    def emit(s)
      process(Parser::CurrentRuby.parse(s)) + cleanup()
    end

    protected

    def process(node)
      case node.type
      when :begin
        result = node.children.map { |child| process(child) }.join("\n")
        if assignment? node.children[-1]
          result << process_load(@last_store)
        end
        result
      when :send
        process_message(*node.children)
      when :lvasgn
        process(node.children[1]) + process_store(node.children[0])
      when :op_asgn
        process_op_assign(*node.children)
      when :lvar
        process_load(node.children[0])
      when :int, :float
        val = node.children[0]
        val < 0 ? "_#{val.abs}" : val.to_s
      when :def
        process_def(*node.children)
      when :block
        process_loop(*node.children)
      else
        fail UnimplementedNodeError, "Unknown node type #{node.type}"
      end
    end

    # If a is nil, assumed to be top-of-stack.
    def process_binop(a, op, second)
      ar = a.nil? ? '' : process(a)
      [ar, process(second), op].join(' ')
    end

    def process_message(invocant, message, *args)
      case
      when [:+, :-, :*, :/].include?(message)
        process_binop(invocant, message, args[0])
      when message == :to_r
        process(invocant)
      when message == :to_i
        'K 0k ' << process(invocant) << ' 1/ rk'
      when invocant.nil? && message.length == 1
        # dc function call
        process(args[0]) + "l#{message}x"
      else
        fail UnimplementedNodeError, "Unknown message #{message}"
      end
    end

    def assignment?(node)
      [:lvasgn, :op_asgn].include? node.type
    end

    def process_load(var)
      "l#{register(var)}"
    end

    def process_store(var)
      @last_store = var
      "S#{register(var)}"
    end

    def process_op_assign(lvasgn, op, val)
      reg = lvasgn.children[0]
      result = process_load(reg)
      result << process_binop(nil, op, val)
      result << process_store(reg)
    end

    def process_def(name, args, code)
      if name.length > 1
        fail InvalidNameError, "name must be a single character, not #{name}"
      end
      if args.children.length > 1
        fail NotImplementedError, "multiple arguments not supported"
      end
      gen = DC::Generator.new
      result = '['
      result << gen.process_store(args.children[0].children[0])
      result << gen.process(code)
      result << "]S#{name}"
    end

    # var is a Symbol for variables and an Integer for code.
    def register(var)
      @registers[var] ||= (64 + @registers.length).chr('ASCII-8BIT')
    end

    def next_anonymous_register
      @anonymous_reg += 1
    end

    def process_condition(condition, arg, code_reg)
      invocant, message = *condition.children
      case message
      when :times
        setup = '0' << process_store(arg)
        test = process_load(arg) << '1+d' << process_store(arg)
        test << process(invocant) << ">#{register(code_reg)}"
      else
        fail NotImplementedError, "unknown message #{message} in condition"
      end
      [setup, test]
    end

    def process_loop(condition, args, code)
      if args.children.length > 1
        fail NotImplementedError, 'multiple arguments to block not supported'
      end
      arg = args.children[0].children[0]
      code_dc = process(code)
      code_reg = next_anonymous_register
      setup, test = process_condition(condition, arg, code_reg)
      result = setup
      result << '[' << code_dc << test << ']'
      result << process_store(code_reg)
      result << process_load(code_reg) << 'x'
      result
    end

    def cleanup
      s = ''
      @registers.values.each do |reg|
        s << "L#{reg} R"
      end
      s
    end
  end
end
