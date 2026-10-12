# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flex_columns/version'

Gem::Specification.new do |s|
  s.name          = "flex_columns"
  s.version       = FlexColumns::VERSION
  s.authors       = ["Andrew Geweke"]
  s.email         = ["andrew@geweke.org"]
  s.homepage      = "https://github.com/ageweke/flex_columns"
  s.description   = %q{Schema-free, structured JSON storage inside a RDBMS.}
  s.summary       = %q{Schema-free, structured JSON storage inside a RDBMS.}
  s.license       = "MIT"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency 'json', '< 3'

  s.add_development_dependency "rake", ">= 13"
  s.add_development_dependency "rspec", "~> 3.12"

  ar_version = ENV['FLEX_COLUMNS_AR_TEST_VERSION']
  ar_version = ar_version.strip if ar_version

  version_spec = case ar_version
  when nil then [ ">= 3.0", "< 8" ]
  when 'master' then nil
  else [ "=#{ar_version}" ]
  end

  if version_spec
    s.add_dependency("activerecord", *version_spec)
  end

  s.add_dependency "activesupport", ">= 3.0", "< 8"

  require File.expand_path(File.join(File.dirname(__FILE__), 'spec', 'flex_columns', 'helpers', 'database_helper'))
  database_gem_name = FlexColumns::Helpers::DatabaseHelper.maybe_database_gem_name

  if database_gem_name == 'sqlite3' && ar_version && ar_version =~ /\A\d/ && Gem::Version.new(ar_version) < Gem::Version.new('7.1')
    # ActiveRecord before 7.1 does not accept sqlite3 2.x.
    s.add_development_dependency(database_gem_name, '~> 1.4')
  elsif database_gem_name
    s.add_development_dependency(database_gem_name)
  end
end
