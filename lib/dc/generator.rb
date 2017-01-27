require 'set'

require 'dc/exception'

# A desk calculator.
module DC
  # Shut up the parser gem.
  begin
    oldv = $VERBOSE
    $VERBOSE = nil
    require 'parser/current'
  ensure
    $VERBOSE = oldv
  end

  class GeneratorError < DC::Exception
  end

  class UnimplementedNodeError < GeneratorError
  end

  class InvalidNameError < GeneratorError
  end

  class GeneratorStackFrameError < GeneratorError
  end

  # A stack frame for the generator.
  #
  # This class creates a frame in the frames variable for each macro that is
  # called, so that the macro level can be popped appropriately when a return or
  # break occurs.
  class GeneratorStackFrame
    def initialize(stack)
      stack.push(object_id)
      f = lambda do |id|
        raise GeneratorStackFrameError, 'frame mismatch' if id != stack.pop
      end
      ObjectSpace.define_finalizer self, f
    end
  end

  # A class to generate dc code from Ruby.
  #
  # This class is intentionally designed to be very stupid.  It will never learn
  # about more types than Float, Integer, and Rational.  It has only the most
  # rudimentary knowledge about Ruby.  It is designed simply to make it easier
  # to write and test implementations of the math library, and hopefully to aid
  # others in developing additional useful functions.
  class Generator
    def initialize(toplevel = false, options = {})
      @toplevel = toplevel
      @code_reg = 0
      @registers = {}
      @code_registers = {}
      @frames = []
      @ignored_functions = options[:ignored_functions] || []
      @options = options
      # These are variables used in Ruby for which no code will be emitted.
      # Generally, this includes instantiations of the math library class.
      @stubs = Set.new
    end

    def emit(s)
      _frame = GeneratorStackFrame.new(@frames)
      prologue + process(Parser::CurrentRuby.parse(s)) + epilogue
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
        process_lvasgn(*node.children)
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
      when :if
        process_conditional(*node.children)
      when :while
        process_while(*node.children)
      when :break
        '2Q'
      when :return
        process(*node.children) << " #{@frames.length * 2}Q"
      else
        raise UnimplementedNodeError,
              "Unknown node type #{node.type} (#{node.inspect})"
      end
    end

    def process_lvasgn(first, second)
      if second.is_a?(Parser::AST::Node) &&
         second.type == :send &&
         second.children[1] == :new
        mark_stub(first)
        return ''
      end
      process(second) + process_store(first)
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
      case invocant.type
      when :const
        # class method call
        message.length == 1
      when :send
        # method call
        invocant.children[1] == :new
      when :lvar
        # method call on instantiated object
        stub?(invocant.children[0])
      else
        false
      end
    end

    def special_method?(_invocant, message)
      [:ibase, :scale, :ibase=, :scale=].include?(message)
    end

    # Process a message sent to a variable.
    #
    # The messages that can be sent are restricted to a certain limited subset.
    # :to_r is a no-op and :to_i truncates to an integer. All single-character
    # function calls are converted to a call to the macro of the same name.
    # :truncate serves only to apply the current scale to the value; its
    # argument is ignored.
    def process_message(invocant, message, *args)
      puts "msg: #{message.inspect}; invocant #{invocant.inspect} #{args.inspect}"
      if [:+, :-, :*, :/, :%].include?(message)
        process_binop(invocant, message, args[0])
      elsif message == :to_r
        process(invocant)
      elsif message == :to_i
        'K 0k ' << process(invocant) << ' 1/ rk'
      elsif message == :-@
        '0 ' << process(invocant) << ' -'
      elsif invocant.nil? && message == :length
        # This is the bc length function, because that's what's required to
        # implement algorithms effectively.  The difference between that and Z
        # is that Z ignores leading zeros to the right of the radix point, while
        # length counts them.  Essentially, the result is X if X is larger than
        # Z, and Z otherwise.
        s = process(args[0])
        s << 'd XSa ZSb [la]Sc[lb]Sd lbla>c lbla!>d '
        s << ('a'..'d').map { |reg| "L#{reg}#{drop}" }.join(' ')
        s
      elsif invocant.nil? && message.length == 1
        # dc function call
        process(args[0]) + "l#{message}x"
      elsif message == :truncate
        process(invocant) + ' 1/'
      elsif message == :puts
        ''
      elsif special_method?(invocant, message)
        smessage = message.to_s
        if smessage.end_with? '='
          process(args[0]) + process_store(smessage.chop.to_sym)
        else
          process_load(message)
        end
      elsif instantiation?(invocant, message)
        ''
      elsif function_call?(invocant, message)
        # dc function call (math library)
        process(args[0]) + "l#{message}x"
      else
        raise UnimplementedNodeError, "Unknown message #{message}"
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
      [
        debug_store(var),
        " #{register(var)}:#{data_register}",
      ].join
    end

    def code_register?(var)
      @code_registers.include? var
    end

    def process_code_load(var)
      "l#{code_register(var)}"
    end

    def process_code_store(var, preallocate = false)
      (code_register?(var) || preallocate ? 's' : 'S') + code_register(var)
    end

    def process_op_assign(lvasgn, op, val)
      reg = lvasgn.children[0]
      result = process_load(reg)
      result << process_binop(nil, op, val)
      result << process_store(reg)
    end

    def process_def(name, args, code)
      return if /\A(?:initialize|length|(?:ibase|scale)=?)\z/ =~ name
      return if @ignored_functions.include? name
      puts "ignored #{@ignored_functions.inspect}: name #{name.inspect}"
      if name.length > 1
        raise InvalidNameError, "name must be a single character, not #{name}"
      end
      if args.children.length > 1
        raise NotImplementedError, 'multiple arguments not supported'
      end
      gen = DC::Generator.new(false, debug: @options[:debug],
                              ignored_functions: @ignored_functions)
      result = '['
      result << gen.prologue
      result << gen.debug("start #{name}")
      result << gen.process_store(args.children[0].children[0])
      result << gen.process(code)
      result << gen.debug("end #{name}")
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

    def process_for_loop(startval, endval, op, comparison, arg)
      startval = startval.is_a?(::Numeric) ? startval.to_s : process(startval)
      endval = endval.is_a?(::Numeric) ? endval.to_s : process(endval)

      setup = startval << process_store(arg)
      inc = process_load(arg) << "1#{op}" << process_store(arg)
      test = process_load(arg) << endval << comparison.to_s
      [setup, inc, test]
    end

    def process_condition(condition, arg)
      invocant, message = *condition.children
      case message
      when :times
        process_for_loop(0, invocant, :+, :>, arg)
      when :reverse_each
        range = invocant.children[0]
        if invocant.type != :begin || range.type != :irange
          raise NotImplementedError, 'bad invocant for reverse_each'
        end
        process_for_loop(range.children[1], range.children[0], :-, '!>', arg)
      when :each
        range = invocant.children[0]
        if invocant.type != :begin || range.type != :irange
          raise NotImplementedError, 'bad invocant for reverse_each'
        end
        process_for_loop(range.children[0], range.children[1], :+, '!<', arg)
      else
        raise NotImplementedError, "unknown message #{message} in condition"
      end
    end

    def process_loop(condition, args, code)
      if args.children.length > 1
        raise NotImplementedError, 'multiple arguments to block not supported'
      end
      if args.children.empty?
        setup = inc = ''
        # Always true.
        test = '1 1='
      else
        arg = args.children[0].children[0]
        setup, inc, test = process_condition(condition, arg)
      end
      code_dc = process(code, true)
      process_branch(test, setup, code_dc + inc, '', true)
    end

    # We need the ability to be able to pop any stacks we've allocated for code
    # whether or not they've been used.  However, the only way to know if
    # they've been used is to run the code.  To ensure we always clean up
    # properly, we preallocate any stacks we use by pushing an empty macro on
    # them, and then unconditionally pop those stacks in the epilogue.
    def preallocate_registers(range)
      range.map { |r| "[]S#{code_register(r)}" }.join(' ')
    end

    def process_comparison(cmp)
      # 1 2 >a triggers
      ops = {
        :== => '=',
        :!= => '!=',
        :> =>  '>',
        :< =>  '<',
        :>= => '!<',
        :<= => '!>',
      }
      result = process(cmp.children[2]) << ' '
      result << process(cmp.children[0]) << ' '
      result << ops[cmp.children[1]]
    end

    def process_conditional(cmp, iftrue, iffalse)
      process_branch(process_comparison(cmp), '', process(iftrue), iffalse)
    end

    def process_while(cmp, body)
      process_branch(process_comparison(cmp), '', process(body, true), '', true)
    end

    # This handles the implementation of branches, both loops and conditionals.
    # The main difference is that for loops, the true code is executed again if
    # the condition holds.  Conditionals can also have a false branch, but this
    # is not yet implemented.
    def process_branch(cmp, setup, iftrue, _iffalse, isloop = false)
      _frame = isloop ? GeneratorStackFrame.new(@frames) : nil
      code_reg = next_code_register
      cmp << code_register(code_reg)
      [
        setup,
        '[', debug("macro #{code_reg}"), iftrue,
        (isloop ? debug("cmp #{code_reg}") << cmp : ''), ']',
        process_code_store(code_reg),
        preallocate_registers((code_reg + 1)..@code_reg),
        (isloop ? '[' << cmp << ']x' : cmp)
      ].join
    end

    def debug(text)
      return '' unless @options[:debug]
      "\n[#{text}]p #{drop}\n"
    end

    def debug_store(var)
      return '' unless @options[:debug]
      "\n[Storing ]n dn [ in #{var}\n]n\n"
    end

    def process_module(_name, block)
      process(block)
    end

    def process_class(_name, _parent, block)
      process(block)
    end

    def prologue
      reg = data_register
      @toplevel ? '' : "0S#{reg} I0:#{reg} Ai [[trap]r "
    end

    def epilogue
      s = ''
      reg = data_register
      @code_registers.values.each do |r|
        s << "L#{r}#{drop} "
      end
      s << "]x 0;#{reg}i L#{reg}#{drop} rZ4-+" unless @toplevel
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
