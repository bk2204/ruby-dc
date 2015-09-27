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

      def e(x)
        s = scale
        ib = ibase
        result = 1
        accum = 1.to_r
        # Rough heuristic.
        iters = ((s + 10) * 6).to_i
        self.scale = 0.5 * x + iters
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
    end
  end
end
