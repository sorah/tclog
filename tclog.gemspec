# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{tclog}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Shota Fukumori"]
  s.date = %q{2010-12-25}
  s.description = %q{Parser for etconsole.log of TrueCombat:Elite (TC:E)}
  s.email = %q{sorah@tubusu.net}
  s.extra_rdoc_files = [
    "README.mkd"
  ]
  s.files = [
    "README.mkd",
     "Rakefile",
     "VERSION",
     "lib/tclog.rb",
     "misc/bctest.log",
     "misc/bctest2.log",
     "misc/ctftest.log",
     "misc/objtest.log",
     "misc/test.log",
     "spec/tclog_spec.rb",
     "tclog.gemspec"
  ]
  s.homepage = %q{http://github.com/sorah/tclog}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Parser for etconsole.log of TrueCombat:Elite (TC:E)}
  s.test_files = [
    "spec/tclog_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
