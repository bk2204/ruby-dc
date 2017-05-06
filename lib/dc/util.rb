require 'set'

require 'dc/exception'
require 'dc/math'

module DC
  # A set of utility functions.
  module Util
    class << self
      protected

      # Converts a value into its integral and fractional components.
      def split(x)
        i = x.to_i
        frac = x - i
        [i, frac]
      end

      # Appends the integral part of x in the given base to the string,
      # returning the fractional part of x.
      def append_integral(s, x, base)
        i, frac = split(x)
        s << i.to_s(base)
        frac
      end
    end

    def self.stringify(x, scale, base = 10)
      sign = x < 0 ? '-' : ''
      x = x.abs.to_r.truncate(scale)
      s = ''
      frac = append_integral(s, x, base)
      s << '.' if scale > 0
      scale.times do
        frac *= base
        frac = append_integral(s, frac, base)
      end
      sign + s
    end

    def self.length(x, scale)
      stringify(x, scale).sub(/^-?0\.0*/, '.').gsub(/[.-]/, '').length
    end

    def self.scale(x, scale)
      stringify(x, scale).split('.')[1].to_s.length
    end
  end
end
