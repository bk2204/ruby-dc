module DC
  module Math
    class Library
      def initialize(calc)
        @calc = calc
      end

      def scale
        @calc.scale.to_i
      end

      def scale=(x)
        @calc.scale = x.to_i
      end

      def ibase
        @calc.ibase.to_i
      end

      def ibase=(x)
        @calc.ibase = x.to_i
      end

      def length(x)
        DC::Util.length(x, scale)
      end

      def e(x)
        s = scale
        ib = ibase
        result = 1
        accum = 1.to_r
        # Rough heuristic.
        iters = ((s + 10) * 6).to_i
        self.scale = 0.5 * x + (iters / 10) + 10
        iters.times do |i|
          n = i + 1
          accum *= x
          accum /= n
          result += accum
        end
        self.scale = s
        self.ibase = ib
        result.to_r.truncate(s)
      end

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
