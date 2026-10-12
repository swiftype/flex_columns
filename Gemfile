source 'https://rubygems.org'

# Specify your gem's dependencies in flex_columns.gemspec
gemspec

ar_version = ENV['FLEX_COLUMNS_AR_TEST_VERSION']
ar_version = ar_version.strip if ar_version

version_spec = case ar_version
when nil then nil
when 'master' then { :git => 'git://github.com/rails/activerecord.git' }
else "=#{ar_version}"
end

if version_spec
  gem("activerecord", version_spec)
end

# concurrent-ruby 1.3.5 dropped its implicit require of 'logger', which breaks ActiveSupport < 7.1.
gem("concurrent-ruby", "< 1.3.5") if ar_version && ar_version =~ /\A[0-6]\./
