require 'parser/current'
require 'set'

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
    def initialize(toplevel = false)
      @toplevel = toplevel
      @code_reg = 0
      @registers = {}
      @code_registers = {}
      # These are variables used in Ruby for which no code will be emitted.
      # Generally, this includes instantiations of the math library class.
      @stubs = Set.new
    end

    def emit(s)
      prologue() + process(Parser::CurrentRuby.parse(s)) + epilogue()
    end

    protected

    # Processes a node.  If anonymous is set and the node is a :begin node,
    # don't perform the implicit final load.
    def process(node, anonymous = false)
      case node.type
      when :begin
        result = node.children.map { |child| process(child) }.join("\n")
        if !anonymous && assignment?(node.children[-1])
          result << process_load(@last_store)
        end
        result
      when :send
        process_message(*node.children)
      when :lvasgn
        if node.children[1].is_a?(Parser::AST::Node) &&
           node.children[1].type == :send &&
           node.children[1].children[1] == :new
          mark_stub(node.children[0])
          return ''
        end
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
      when :defs
        process_defs(*node.children)
      when :block
        process_loop(*node.children)
      when :module
        process_module(*node.children)
      when :class
        process_class(*node.children)
      else
        fail UnimplementedNodeError, "Unknown node type #{node.type}"
      end
    end

    # If a is nil, assumed to be top-of-stack.
    def process_binop(a, op, second)
      ar = a.nil? ? '' : process(a)
      [ar, process(second), op].join(' ')
    end

    def instantiation?(invocant, message)
      return false unless invocant.is_a?(Parser::AST::Node)
      return false unless invocant.type == :const
      message == :new
    end

    def function_call?(invocant, message)
      return false unless invocant.is_a?(Parser::AST::Node)
      type = invocant.type
      # class method call
      return true if type == :const && message.length == 1
      # method call
      return true if type == :send && invocant.children[1] == :new
      # method call on instantiated object
      return true if type == :lvar && stub?(invocant.children[0])
      false
    end

    def special_method?(_invocant, message)
      [:ibase, :scale, :ibase=, :scale=].include?(message)
    end

    def process_message(invocant, message, *args)
      case
      when [:+, :-, :*, :/].include?(message)
        process_binop(invocant, message, args[0])
      when message == :to_r
        process(invocant)
      when message == :to_i
        'K 0k ' << process(invocant) << ' 1/ rk'
      when invocant.nil? && message == :length
        # This is the bc length function, because that's what's required to
        # implement algorithms effectively.  The difference between that and Z
        # is that Z ignores leading zeros to the right of the radix point, while
        # length counts them.  Essentially, the result is X if X is larger than
        # Z, and Z otherwise.
        s = process(args[0])
        s << 'd XSa ZSb [la]Sc[lb]Sd lbla>c lbla!>d LaR LbR LcR LdR'
        s
      when invocant.nil? && message.length == 1
        # dc function call
        process(args[0]) + "l#{message}x"
      when message == :truncate
        process(invocant) + ' 1/'
      when special_method?(invocant, message)
        smessage = message.to_s
        if smessage.end_with? '='
          process(args[0]) + process_store(smessage.chop.to_sym)
        else
          process_load(message)
        end
      when instantiation?(invocant, message)
        ''
      when function_call?(invocant, message)
        # dc function call (math library)
        process(args[0]) + "l#{message}x"
      else
        fail UnimplementedNodeError, "Unknown message #{message}"
      end
    end

    def assignment?(node)
      [:lvasgn, :op_asgn].include? node.type
    end

    def mark_stub(var)
      @stubs << var
    end

    def stub?(var)
      @stubs.include? var
    end

    def process_load(var)
      return '' if stub? var
      return 'K' if var == :scale
      return 'I' if var == :ibase
      " #{register(var)};#{data_register}"
    end

    def process_store(var)
      return '' if stub? var
      return 'k' if var == :scale
      return 'i' if var == :ibase
      @last_store = var
      " #{register(var)}:#{data_register}"
    end

    def code_register?(var)
      @code_registers.include? var
    end

    def process_code_load(var)
      "l#{code_register(var)}"
    end

    def process_code_store(var)
      (code_register?(var) ? 's' : 'S') + code_register(var)
    end

    def process_op_assign(lvasgn, op, val)
      reg = lvasgn.children[0]
      result = process_load(reg)
      result << process_binop(nil, op, val)
      result << process_store(reg)
    end

    def process_def(name, args, code)
      return if /\A(?:initialize|length|(?:ibase|scale)=?)\z/.match name
      if name.length > 1
        fail InvalidNameError, "name must be a single character, not #{name}"
      end
      if args.children.length > 1
        fail NotImplementedError, 'multiple arguments not supported'
      end
      gen = DC::Generator.new
      result = '['
      result << gen.prologue
      result << gen.process_store(args.children[0].children[0])
      result << gen.process(code)
      result << gen.epilogue
      result << "]S#{name}"
    end

    def process_defs(*args)
      process_def(*args[1..-1])
    end

    # The register that is used for arrays.
    def data_register
      '@'
    end

    # var is a Symbol for variables and an Integer for code.  These are not
    # actually registers, but index values for the array specified with
    # data_register.  Single-digit index values are reserved for the prologue
    # and epilogue.
    def register(var)
      @registers[var] ||= (10 + @registers.length)
    end

    def next_code_register
      @code_reg += 1
    end

    def code_register(var)
      @code_registers[var] ||= (65 + @code_registers.length).chr('ASCII-8BIT')
    end

    def process_for_loop(startval, endval, op, comparison, arg, code_reg)
      startval = startval.is_a?(::Numeric) ? startval.to_s : process(startval)
      endval = endval.is_a?(::Numeric) ? endval.to_s : process(endval)

      setup = startval << process_store(arg)
      test = process_load(arg) << "1#{op}d" << process_store(arg)
      test << endval << comparison.to_s << code_register(code_reg)
      [setup, test]
    end

    def process_condition(condition, arg, code_reg)
      invocant, message = *condition.children
      case message
      when :times
        process_for_loop(0, invocant, :+, :>, arg, code_reg)
      when :reverse_each
        range = invocant.children[0]
        if invocant.type != :begin || range.type != :irange
          fail NotImplementedError, 'bad invocant for reverse_each'
        end
        process_for_loop(range.children[1], range.children[0], :-, '!>', arg,
                         code_reg)
      when :each
        range = invocant.children[0]
        if invocant.type != :begin || range.type != :irange
          fail NotImplementedError, 'bad invocant for reverse_each'
        end
        process_for_loop(range.children[0], range.children[1], :+, '!<', arg,
                         code_reg)
      else
        fail NotImplementedError, "unknown message #{message} in condition"
      end
    end

    def process_loop(condition, args, code)
      if args.children.length > 1
        fail NotImplementedError, 'multiple arguments to block not supported'
      end
      arg = args.children[0].children[0]
      code_dc = process(code, true)
      code_reg = next_code_register
      setup, test = process_condition(condition, arg, code_reg)
      result = setup
      result << '[' << code_dc << test << ']'
      result << process_code_store(code_reg)
      result << process_code_load(code_reg) << 'x'
      result
    end

    def process_module(_name, block)
      process(block)
    end

    def process_class(_name, _parent, block)
      process(block)
    end

    def prologue
      reg = data_register
      @toplevel ? '' : "0S#{reg} I0:#{reg} Ai"
    end

    def epilogue
      s = ''
      reg = data_register
      @code_registers.values.each do |r|
        s << "L#{r}#{drop} "
      end
      s << "0;#{reg}i L#{reg}#{drop}" unless @toplevel
      s
    end

    # We could use the FreeBSD "R" for this, but that doesn't work on GNU dc.
    # Convert the top of stack to a number, duplicate it, and subtract, which
    # gives us 0.  Then add that to the current scale.  Unlike some others,
    # this technique works even if there is nothing else on the stack.
    def drop
      'Xd-K+k'
    end
  end
end
