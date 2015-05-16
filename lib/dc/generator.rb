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
        node.children.map { |child| process(child) }.join("\n")
      when :send
        process_message(*(node.children))
      when :lvasgn
        process(node.children[1]) + "S#{register(node.children[0])}"
      when :lvar
        "l#{register(node.children[0])}"
      when :int
        val = node.children[0]
        val < 0 ? "_#{val.abs}" : val.to_s
      else
        fail UnimplementedNodeError, "Unknown node type #{node.type}"
      end
    end

    def process_message(invocant, message, *args)
      case
      when [:+, :-, :*, :/].include?(message)
        [process(invocant), process(args[0]), message].join(' ')
      else
        fail UnimplementedNodeError, "Unknown message #{message}"
      end
    end

    def register(var)
      @registers[var] ||= (128 + @registers.length).chr('ASCII-8BIT')
    end

    def cleanup
      s = ''
      @registers.values.each do |reg|
        s << "L#{reg} d-+"
      end
      s
    end
  end
end
