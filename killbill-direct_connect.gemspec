version = File.read(File.expand_path('../VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name        = 'killbill-direct_connect'
  s.version     = version
  s.summary     = 'Plugin to use DirectConnect as a gateway.'
  s.description = 'Kill Bill payment plugin for DirectConnect.'

  s.required_ruby_version = '>= 1.9.3'

  s.license = 'Apache License (2.0)'

  s.author   = 'Kill Bill core team'
  s.email    = 'killbilling-users@googlegroups.com'
  s.homepage = 'http://kill-bill.org'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.rdoc_options << '--exclude' << '.'

  s.add_dependency 'killbill', '~> 3.2.4'
  s.add_dependency 'activemerchant'
  s.add_dependency('active_utils', '~> 2.2.0')
  s.add_dependency 'offsite_payments', '~> 2.0.1'
  s.add_dependency 'activerecord', '~> 4.1.0'
  s.add_dependency 'actionpack', '~> 4.1.0'
  s.add_dependency 'actionview', '~> 4.1.0'
  s.add_dependency 'activesupport', '~> 4.1.0'
  s.add_dependency 'money', '~> 6.5.1'
  s.add_dependency 'monetize', '~> 1.1.0'
  s.add_dependency 'i18n', '~> 0.6.4'
  s.add_dependency 'nokogiri', '1.6.1'
  s.add_dependency 'sinatra', '~> 1.3.4'
  if defined?(JRUBY_VERSION)
    s.add_dependency 'activerecord-jdbcmysql-adapter', '~> 1.3.7'
    # Required to avoid errors like java.lang.NoClassDefFoundError: org/bouncycastle/asn1/DERBoolean
    s.add_dependency 'jruby-openssl', '~> 0.9.4'
  end

  s.add_development_dependency 'jbundler', '~> 0.4.1'
  s.add_development_dependency 'rake', '>= 10.0.0'
  s.add_development_dependency 'rspec', '~> 2.12.0'
  s.add_development_dependency('mocha', '~> 0.13.0')
  
  if defined?(JRUBY_VERSION)
    s.add_development_dependency 'activerecord-jdbcsqlite3-adapter', '~> 1.3.7'
  else
    s.add_development_dependency 'sqlite3', '~> 1.3.7'
  end
end
