# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)
require "active_admin_filters_defaults/version"

Gem::Specification.new do |s|
  s.name        = "active_admin_filters_defaults"
  s.version     = ActiveAdminFiltersDefaults::VERSION
  s.authors     = ["Igor Fedoronchuk"]
  s.email       = ["fedoronchuk@gmail.com"]
  s.homepage    = "https://github.com/activeadmin-plugins/active_admin_filters_defaults"
  s.license     = "MIT"
  s.summary     = "Default values for Active Admin index filters"
  s.description = "Lets an Active Admin resource declare what its index filters on when opened " \
                  "without filters of its own: filter :state_eq, default: 'active'"

  s.required_ruby_version = ">= 3.0"
  s.add_dependency "activeadmin", ">= 3.5", "< 4"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]

  s.metadata = {
    "homepage_uri" => s.homepage,
    "source_code_uri" => s.homepage,
    "rubygems_mfa_required" => "true"
  }
end
