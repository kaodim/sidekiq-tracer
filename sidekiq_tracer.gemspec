$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "sidekiq_tracer/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "sidekiq_tracer"
  s.version     = SidekiqTracer::VERSION
  s.authors     = ["daniel"]
  s.email       = ["daniel.lee@kaodim.com"]
  s.homepage    = "https://github.com/kaodim/ada"
  s.summary     = "A sidekiq tracer extension"
  s.description = "Correlate sidekiq logs with web api request"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 5.0.6", "< 6.0"
  s.add_dependency "lograge-sql", "~> 1.1.0"
end
