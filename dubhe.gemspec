# frozen_string_literal: true

require_relative "lib/dubhe/version"

Gem::Specification.new do |spec|
  spec.name = "dubhe"
  spec.version = Dubhe::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "A safe feeds-first document reader core"
  spec.description = "Dubhe provides file-backed reader storage, feed fetching, " \
    "sanitization policies, and source APIs for static documents and mail."
  spec.homepage = "https://github.com/noxdea/dubhe"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "README.md", "CHANGELOG.md", "LICENSE.txt", "docs/**/*.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "iklil", "~> 0.1"
  spec.add_dependency "jabbah", "~> 0.1"
  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "cgi", "~> 0.4"
  spec.add_dependency "rexml", "~> 3.4"
  spec.add_dependency "ukdah", "~> 0.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
