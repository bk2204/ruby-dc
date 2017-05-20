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
        x = x.to_r
        return 0 if x <= 0

        t = scale

        f = 1
        s = length(x)

        self.scale = 0
        a = ((2.31 * s) / 1).to_i
        s = (t + length(a) + 2).to_i

        while x > 2
          self.scale = 0
          self.scale = (length(x) + 1).to_i
          self.scale = s if scale < s
          x = ::Math.sqrt(x).to_r
          f *= 2
        end
        while x < 0.5
          self.scale = 0
          self.scale = length(x) / 2 + 1
          self.scale = s if scale < s
          x = ::Math.sqrt(x).to_r
          f *= 2
        end

        self.scale = 0
        self.scale = t + length(f) + length(1.05 * (t + length(f))) + 1
        u = (x - 1).to_r / (x + 1)
        s = u * u
        self.scale = t + 2
        b = 2 * f
        c = b.to_r
        d = 1.to_r
        e = 1.to_r

        result = 1
        a = 3
        loop do
          b *= s
          c = c * a + d * b
          d *= a
          g = (c / d).truncate(t + 2)
          if g == e
            result = u * c / d
            self.scale = t
            break
          end
          e = g
          a += 2
        end

        result.to_r.truncate(t.to_i)
      end
    end
  end
end
