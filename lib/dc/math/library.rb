module DC
  module Math
    # The math library for dc.
    #
    # This code is designed such that it can be used both in Ruby and, via the
    # code generator, in dc.  As such, it is simpler, more verbose, and
    # necessarily less expressive than typical Ruby code would be.
    class Library
      def initialize(calc)
        @calc = calc
      end

      # Get the scale of the calculator.
      #
      # In dc, calls to this function invoke the k operator.
      def scale(x = nil)
        return DC::Util.scale(x, @calc.scale.to_i) if x
        @calc.scale.to_i
      end

      # Set the scale of the calculator.
      #
      # In dc, calls to this function invoke the K operator.
      def scale=(x)
        @calc.scale = x.to_i
      end

      # Set the input base of the calculator.
      #
      # In dc, calls to this function invoke the i operator.
      def ibase
        @calc.ibase.to_i
      end

      # Set the input base of the calculator.
      #
      # In dc, calls to this function invoke the i operator.
      def ibase=(x)
        @calc.ibase = x.to_i
      end

      def length(x)
        DC::Util.length(x, scale)
      end

      # The exponential function, e^x.
      def e(x)
        x = x.to_r
        r = ibase
        ibase = 10
        t = scale.to_r
        scale = 0
        scale = ((0.435 * x) / 1).to_i if x > 0
        scale += (t + length(scale + t) + 1).to_i
        s = scale

        result = 1
        w = 0
        if x < 0
          x = -x
          w = 1
        end
        y = 0
        while x > 2
          x = (x / 2).truncate(s)
          y += 1
        end

        a = 1.to_r
        b = 1.to_r
        c = b
        d = 1.to_r
        e = 1.to_r
        loop do
          b *= x
          c = c * a + b
          d *= a
          g = (c / d).truncate(s)
          if g == e
            g = (g / 1).truncate(s)
            while y != 0
              g *= g
              y -= 1
            end
            self.scale = t
            ibase = r
            result = 1 / g if w == 1
            result = g / 1 if w == 0
            break
          end
          e = g
          a += 1
        end
        result.to_r.truncate(t.to_i)
      end

      # The natural logarithm function, ln x.
      def l(x)
        s = scale
        ib = ibase
        # Rough heuristic.
        iters = ((s + 20) * 10).to_i
        self.scale = s * 4
        x = x.to_r
        accum = 1.to_r
        y = (x - 1) / (x + 1)
        y2 = y * y
        (0..iters).reverse_each do |i|
          n = i * 2 + 1
          f = 1 / n.to_r
          r = accum * y2
          accum = (r + f).to_r.truncate(scale)
        end
        result = accum * 2 * y
        self.scale = s
        self.ibase = ib
        result.to_r.truncate(s)
      end
    end
  end
end
