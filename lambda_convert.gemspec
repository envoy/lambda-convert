Gem::Specification.new do |s|
  s.name        = 'lambda_convert'
  s.version     = '0.0.1'
  s.date        = '2017-01-20'
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
end