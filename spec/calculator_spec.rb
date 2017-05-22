require_relative 'spec_helper'

describe DC::Calculator do
  it 'should report the extensions supported' do
    c = DC::Calculator.new(StringIO.new, StringIO.new, gnu: true)
    expect(c.extensions).to eq [:gnu]

    c = DC::Calculator.new(StringIO.new, StringIO.new, gnu: true, freebsd: true)
    expect(c.extensions).to include :gnu
    expect(c.extensions).to include :freebsd
  end

  it 'should report the extensions in sorted order' do
    c = DC::Calculator.new(StringIO.new, StringIO.new, gnu: true, freebsd: true)
    expect(c.extensions).to eq %i[freebsd gnu]
  end
end
