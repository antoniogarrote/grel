Gem::Specification.new do |s|
  s.name = "grel"
  s.version = "0.0.1"
  s.platform = Gem::Platform::RUBY
  s.authors = ["Antonio Garrote"]
  s.email = ["antoniogarrote@gmail.com"]
  s.homepage = "https://github.com/antoniogarrote/grel"
  s.summary = %q{Ruby object oriented wrapper for Stardog}
  s.description = %q{idem}

  s.require_paths = ["lib"]
  
  s.add_dependency('stardog-rb')
end