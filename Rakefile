#!/usr/bin/ruby

require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/*.rb'
end

task :build do
  $LOAD_PATH.push File.join(File.dirname(__FILE__), 'lib')
  require 'dc/generator'

  begin
    Dir.mkdir 'build'
  rescue Errno::EEXIST # rubocop:disable Lint/HandleExceptions
    # It's fine if the directory already exists.
  end

  f = File.new('build/dc.library', 'w')
  f.puts DC::Generator.new(true).emit(File.read('lib/dc/math/library.rb'))
end

task all: [:spec, :build]
task default: :all
