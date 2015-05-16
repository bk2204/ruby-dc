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
    def emit(s)
      process(Parser::CurrentRuby.parse(s))
    end

    protected

    def process(node)
      case node.type
      when :send
        process_message(*(node.children))
      when :int
        node.children[0] < 0 ? "_#{node.children[0].abs}" : node.children[0]
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
  end
end
