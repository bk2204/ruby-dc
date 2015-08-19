require_relative 'spec_helper'

# This spec is a sort of integration test.  It produces the SHA-2 initial values
# and round constants to ensure that the calculator is working correctly.
describe DC::Calculator do
  def calc
    output = StringIO.new('', 'w+')
    input = StringIO.new('', 'r')
    DC::Calculator.new(input, output)
  end

  def prime?(x)
    # SHA-512 uses primes up to 409; these values are therefore sufficient to
    # determine primality.
    [2, 3, 5, 7, 11, 13, 17, 19, 23].each do |p|
      return true if x == p
      return false if (x % p) == 0
    end
    true
  end

  it 'should produce the SHA-1 round constants correctly' do
    values = %w(
      5A827999
      6ED9EBA1
      8F1BBCDC
      CA62C1D6
    )
    values.zip([2, 3, 5, 10]).each do |(val, x)|
      c = calc
      c.parse("32k 16o #{x}v 0k 2 30^* 1/p")
      expect(c.output.string).to eq("#{val}\n")
    end
  end

  it 'should produce the SHA-256 initial values correctly' do
    values = %w(
      6A09E667
      BB67AE85
      3C6EF372
      A54FF53A
      510E527F
      9B05688C
      1F83D9AB
      5BE0CD19
    )
    values.zip((2..19).select { |x| prime?(x) }).each do |(val, p)|
      c = calc
      c.parse("32k 16o #{p}v d 0k 1/- 2 32^* 1/p")
      expect(c.output.string).to eq("#{val}\n")
    end
  end

  it 'should produce the SHA-512 initial values correctly' do
    values = %w(
      6A09E667F3BCC908
      BB67AE8584CAA73B
      3C6EF372FE94F82B
      A54FF53A5F1D36F1
      510E527FADE682D1
      9B05688C2B3E6C1F
      1F83D9ABFB41BD6B
      5BE0CD19137E2179
    )
    values.zip((2..19).select { |x| prime?(x) }).each do |(val, p)|
      c = calc
      # Use scale 20 because 2^64 is approximately equal to 10^19.2.  Ensure
      # that more precision than that is not required for correctness.
      c.parse("20k 16o #{p}v d 0k 1/- 2 64^* 1/p")
      expect(c.output.string).to eq("#{val}\n")
    end
  end
end
