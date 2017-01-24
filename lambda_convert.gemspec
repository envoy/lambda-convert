Gem::Specification.new do |s|
  s.name        = 'lambda_convert'
  s.version     = '0.0.5'
  s.date        = '2017-01-23'
  s.summary     = 'AWS Lambda powered drop-in replacement for ImageMagick convert command line tool'
  s.authors     = ['Fang-Pen Lin']
  s.email       = 'fang@envoy.com'
  s.files       = (
    Dir.glob('*/lib/**/*', File::FNM_DOTMATCH) +
    Dir['bin/*'] +
    %w(README.md LICENSE)
  )
  s.bindir      = 'bin'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.license     = 'MIT'
  s.add_runtime_dependency 'aws-sdk', '~> 2.6'
end
