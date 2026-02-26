require_relative "lib/kazhat/version"

Gem::Specification.new do |spec|
  spec.name        = "kazhat"
  spec.version     = Kazhat::VERSION
  spec.authors     = ["Kazhat"]
  spec.summary     = "Real-time video calling and messaging for Rails"
  spec.description = "A mountable Rails engine that adds WebRTC video calling and real-time messaging to any Rails application."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/kazhat/kazhat"

  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "Rakefile"]
  end

  spec.add_dependency "rails", ">= 7.0"

  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "shoulda-matchers", "~> 5.0"
  spec.add_development_dependency "sqlite3"
end
