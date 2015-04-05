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
          expected = (base ** exponent) % modulus
          expect(DC::Math.modexp(base, exponent, modulus)).to eq expected
        end
      end
    end
  end

  it 'should compute square roots accurately' do
    (0..100).each do |x|
      (0..10).each do |scale|
        expected = Math.sqrt(x).round(scale)
        expect(DC::Math.root(x, 2, scale)).to eq expected
      end
    end
  end

  it 'should compute small roots accurately' do
    (1..100).each do |x|
      (0..10).each do |scale|
        (3..7).each do |root|
          expected = (x.to_f ** (1/root.to_f)).round(scale)
          expect(DC::Math.root(x, root, scale)).to eq expected
        end
      end
    end
  end
end