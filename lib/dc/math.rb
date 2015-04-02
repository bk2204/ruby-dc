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
  end
end
