require 'set'

require 'dc/exception'
require 'dc/math'

module DC
  module Util
    def self.stringify(x, scale, base=10)
      base = base.to_i
      i = x.to_i
      temp = x.to_r.truncate(scale)
      frac = temp - i
      s = i.to_s(base)
      s << '.' if scale > 0
      scale.times do
        frac *= base
        value = frac.to_i
        frac -= value
        s << value.to_s(base)
      end
      s
    end

    def self.length(x, scale)
      stringify(x, scale).sub(/^0\.0*/, '.').gsub(/[.-]/, '').length
    end
  end
end
