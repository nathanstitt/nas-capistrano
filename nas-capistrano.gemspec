# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nas/capistrano/version'

Gem::Specification.new do |spec|
    spec.name          = "nas-capistrano"
    spec.version       = Nas::Capistrano::VERSION
    spec.authors       = ["Nathan Stitt"]
    spec.email         = ["nathan@stitt.org"]
    spec.summary       = "Nathan's recipes for Capistrano"
    spec.description   = "Recipes for deploying extjs and asset pipeline projects with capistrano to my domains"

    spec.homepage      = ""
    spec.license       = "MIT"

    spec.files         = `git ls-files`.split($/)
    spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ["lib"]

    spec.add_development_dependency "bundler", "~> 1.3"
    spec.add_development_dependency "rake"
    spec.add_dependency 'capistrano'
end
