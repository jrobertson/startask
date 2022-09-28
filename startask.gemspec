Gem::Specification.new do |s|
  s.name = 'startask'
  s.version = '0.1.0'
  s.summary = 'An experimental gem representing the STAR technique.'
  s.authors = ['James Robertson']
  s.files = Dir["lib/startask.rb"]
  s.add_runtime_dependency('rxfreadwrite', '~> 0.2', '>=0.2.6')
  s.signing_key = '../privatekeys/startask.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/startask'
end
