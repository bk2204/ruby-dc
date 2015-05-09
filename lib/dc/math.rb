require_relative 'calculator'

module DC
  module Math
    def self.modexp(base, exponent, modulus)
      return 1 if exponent == 0
      if exponent < 0 || exponent.to_i != exponent
        fail RangeError, "exponent '#{exponent}' not a non-negative integer"
      end

      exp = exponent
      result = 1
      factor = base
      while exp > 0
        result *= factor if (exp & 1) != 0
        result %= modulus
        exp >>= 1
        factor = factor ** 2
      end

      result
    end

    # Based on the square root algorithm given on the "Newton's method"
    # Wikipedia page.
    def self.root(base, root, scale=nil)
      x0 = base.to_f ** (1 / root.to_f).to_r

      if scale.nil?
        scales = [base, root].map do |v|
          v.respond_to?(:scale) ? v.scale : nil
        end
        scale = scales.reject(&:nil?).max
        return x0 if scale.nil?
      end

      root = root.to_r
      tolerance = 1.to_r / (10.to_r ** (scale + 1))
      epsilon = tolerance ** 2

      f = lambda { |x| (x ** root) - base }
      fprime = lambda { |x| root * (x ** (root-1)) }

      x0 = x0.to_r
      x1 = x0

      # Rough approximation.
      ((scale + 3) * 20).times do
        y = f.call(x0)
        y_deriv = fprime.call(x0)

        break if y_deriv.abs < epsilon

        x1 = x0 - y/y_deriv

        break if (((x1 - x0).abs / x1.abs) < tolerance)

        x0 = x1
      end

      x1.round(scale)
    end
  end
end
