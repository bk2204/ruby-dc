Gem::Specification.new do |s|
  s.name        = 'dc'
  s.version     = '0.1.0'
  s.author      = 'brian m. carlson'
  s.email       = 'sandals@crustytoothpaste.net'
  s.homepage    = 'https://github.com/bk2204/ruby-dc'
  s.summary     = 'An implementation of the dc(1) language'
  s.license     = 'MIT'

  s.add_dependency('parser', '~> 2.1')

  s.add_development_dependency('rake', '~> 10.0')
  s.add_development_dependency('rspec', '~> 3.0')
  s.add_development_dependency('rubocop', '~> 0.49.1')

  s.files  = %w[LICENSE Rakefile README.adoc]
  s.files += Dir.glob('bin/*')
  s.files += Dir.glob('lib/**/*.rb')
end
