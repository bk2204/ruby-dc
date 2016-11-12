require_relative 'calculator'

module DC
  # Implementations of common mathematical algorithms.
  module Math
    # Perform a modular exponentiation.
    #
    # @param base [Rational] the base or mantissa
    # @param exponent [Integer] the exponent
    # @param modulus [Rational] the modulus
    # @return the result of the exponentiation
    #
    # The algorithm is the basic double-and-multiply technique, just extended to
    # rationals instead of integers.
    def self.modexp(base, exponent, modulus)
      return 1 if exponent == 0
      if exponent < 0 || exponent.to_i != exponent
        raise RangeError, "exponent '#{exponent}' not a non-negative integer"
      end

      exp = exponent
      result = 1
      factor = base
      while exp > 0
        result *= factor if (exp & 1) != 0
        result %= modulus
        exp >>= 1
        factor **= 2
      end

      result
    end

    # Compute a root of a number.
    #
    # @param base [Rational] the base
    # @param root [Integer] the root (e.g. 2 for square root)
    # @param scale [Integer] the scale (argument to Rational#truncate)
    # @return the provided root
    #
    # Uses the Newton-Raphson method and is based on the square root algorithm
    # given at https://en.wikipedia.org/wiki/Newton%27s_method.
    def self.root(base, root, scale = nil)
      x0 = base.to_f**(1 / root.to_f).to_r

      if scale.nil?
        scales = [base, root].map do |v|
          v.respond_to?(:scale) ? v.scale : nil
        end
        scale = scales.reject(&:nil?).map(&:to_i).max
        return x0 if scale.nil?
      end

      base = base.to_r
      root = root.to_r
      scale = scale.to_i
      tolerance = 1.to_r / (10.to_r**(scale + 1))
      epsilon = tolerance**2

      f = ->(x) { (x**root) - base }
      fprime = ->(x) { root * (x**(root - 1)) }

      x0 = x0.to_r
      x1 = x0

      # Rough approximation.
      ((scale + 3) * 20).times do
        y = f.call(x0)
        y_deriv = fprime.call(x0)

        break if y_deriv.abs < epsilon

        x1 = x0 - y / y_deriv

        break if ((x1 - x0).abs / x1.abs) < tolerance

        x0 = x1
      end

      x1.truncate(scale)
    end
  end
end
