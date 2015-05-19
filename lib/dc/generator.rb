require 'parser/current'

module DC
  class GeneratorError < StandardError
  end

  class UnimplementedNodeError < GeneratorError
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
      when :int
        val = node.children[0]
        val < 0 ? "_#{val.abs}" : val.to_s
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

    def register(var)
      @registers[var] ||= (64 + @registers.length).chr('ASCII-8BIT')
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
