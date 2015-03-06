if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start do
    add_filter '/spec/'
  end
end

require 'stringio'

require_relative '../lib/dc/calculator'
