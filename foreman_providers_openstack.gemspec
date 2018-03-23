require File.expand_path('../lib/foreman_providers_openstack/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'foreman_providers_openstack'
  s.version     = ForemanProvidersOpenstack::VERSION
  s.license     = 'GPL-3.0'
  s.authors     = ['Adam Grare', 'Ladislav Smola', 'James Wong']
  s.email       = ['agrare@redhat.com', 'lsmola@redhat.com', 'jwong@redhat.com']
  s.homepage    = 'https://github.com/jameswnl/foreman_providers_openstack'
  s.summary     = 'Openstack Provider plugin for Foreman.'
  # also update locale/gemspec.rb
  s.description = 'Openstack Provider plugin for Foreman.'

  s.files = Dir['{app,config,db,lib,locale}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_runtime_dependency "activesupport",        ">= 5.0", "< 5.2"
  s.add_runtime_dependency "bunny",                "~>2.1.0"
  s.add_runtime_dependency "excon",                "~>0.40"
  s.add_runtime_dependency "fog-openstack",        "=0.1.22"
  s.add_runtime_dependency "more_core_extensions", "~>3.2"

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rdoc'
end
