require_relative 'spec_helper'

describe DC::Math do
  it 'should compute modexp correctly for 0 exponent' do
    expect(DC::Math.modexp(5, 0, 10)).to eq 1
    expect(DC::Math.modexp(26, 0, 3)).to eq 1
  end

  it 'should modexp small numbers accurately' do
    (0..100).each do |base|
      (0..10).each do |exponent|
        (2..10).each do |modulus|
          expected = (base**exponent) % modulus
          expect(DC::Math.modexp(base, exponent, modulus)).to eq expected
        end
      end
    end
  end

  it 'should fail when trying to modexp with invalid exponents' do
    expect { DC::Math.modexp(10, -1, 5) }.to raise_exception RangeError
    expect { DC::Math.modexp(10, 0.5, 5) }.to raise_exception RangeError
  end

  it 'should compute square roots accurately' do
    (0..100).each do |x|
      (0..10).each do |scale|
        expected = Math.sqrt(x).to_r.truncate(scale)
        expect(DC::Math.root(x, 2, scale)).to eq expected
      end
    end
  end

  it 'should compute small roots accurately' do
    (1..100).each do |x|
      (0..10).each do |scale|
        (3..7).each do |root|
          if root == 3
            # The other expression provides the wrong value (3) for x == 64.
            expected = Math.cbrt(x).to_r.truncate(scale)
          else
            expected = (x.to_f**(1 / root.to_f)).to_r.truncate(scale)
          end
          expect(DC::Math.root(x, root, scale)).to eq expected
        end
      end
    end
  end

  it 'should detect proper scale if possible' do
    base = DC::Numeric.new(2, 20, 20)
    expect(DC::Math.root(base, 2)).to eq Rational('1.41421356237309504880')
  end

  it 'should compute some expected values accurately' do
    values = %w(
      1.41421356237309504880
      1.73205080756887729352
      2.00000000000000000000
      2.23606797749978969640
      2.44948974278317809819
      2.64575131106459059050
      2.82842712474619009760
      3.00000000000000000000
      3.16227766016837933199
      3.31662479035539984911
      3.46410161513775458705
      3.60555127546398929311
      3.74165738677394138558
      3.87298334620741688517
      4.00000000000000000000
      4.12310562561766054982
      4.24264068711928514640
      4.35889894354067355223
      4.47213595499957939281
      4.58257569495584000658
      4.69041575982342955456
      4.79583152331271954159
      4.89897948556635619639
      5.00000000000000000000
      5.09901951359278483002
      5.19615242270663188058
      5.29150262212918118100
      5.38516480713450403125
      5.47722557505166113456
      5.56776436283002192211
      5.65685424949238019520
      5.74456264653802865985
      5.83095189484530047087
      5.91607978309961604256
      6.00000000000000000000
      6.08276253029821968899
      6.16441400296897645025
      6.24499799839839820584
      6.32455532033675866399
    )
    values.each_with_index do |val, i|
      expect(DC::Math.root(i + 2, 2, 20)).to eq Rational(val)
    end
  end
end
