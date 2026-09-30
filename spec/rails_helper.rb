# frozen_string_literal: true

# Boots the generated sample app. Only the integration specs need this - the unit specs run
# against a stand-in controller and stay in spec_helper.
#
# One app per filter_defaults_mode, selected by APP_MODE - the mode is application
# configuration, so each suite boots its own app and the suites run as separate processes
# (`rake spec` does this). A single rspec invocation must not mix the two directories.

$LOAD_PATH.unshift(File.expand_path("support", __dir__))

ENV["BUNDLE_GEMFILE"] = File.expand_path("../Gemfile", __dir__)
require "bundler"
Bundler.setup

APP_MODE = ENV["APP_MODE"] ||= "redirect"
raise ArgumentError, "APP_MODE must be redirect or implicit, got #{APP_MODE}" unless %w[redirect implicit].include?(APP_MODE)

# A single process boots a single app, so specs of the other mode in the same run would fail
# opaquely - or worse, pass against the wrong app. Refuse loudly instead.
other_mode = APP_MODE == "redirect" ? "implicit" : "redirect"
if RSpec.configuration.files_to_run.any? { |file| file.include?("spec/integration/#{other_mode}/") }
  abort "This run is APP_MODE=#{APP_MODE} but selects specs from spec/integration/#{other_mode}/ - " \
        "the two suites boot different sample apps and must run as separate processes: use `rake spec`."
end

ENV["RAILS_ENV"] = "test"
require "rails"
ENV["RAILS"] = Rails.version
ENV["RAILS_ROOT"] = File.expand_path("rails/rails-#{ENV['RAILS']}-#{APP_MODE}", __dir__)

unless File.exist?(ENV["RAILS_ROOT"])
  # A generation that dies midway leaves a partial app the File.exist? guard would then skip
  # forever - fail the run instead of limping into it.
  system({ "APP_MODE" => APP_MODE }, "rake setup") ||
    abort("rake setup failed - remove #{ENV['RAILS_ROOT']} before retrying")
end

require "active_model"
# Required before Active Admin so that Ransack loads correctly.
require "active_record"
require "action_view"
require "active_admin"
ActiveAdmin.application.load_paths = ["#{ENV['RAILS_ROOT']}/app/admin"]
require "#{ENV['RAILS_ROOT']}/config/environment"

# Specs are about filters, not about signing in.
ActiveAdmin.application.authentication_method = false
ActiveAdmin.application.current_user_method = false

require "rspec/rails"
require "capybara/rails"
require "capybara/rspec"
require "database_cleaner/active_record"
require "capybara_driver"

RSpec.configure do |config|
  config.use_transactional_fixtures = false

  config.before(:suite) do
    ActiveRecord::Migration.maintain_test_schema!
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before { DatabaseCleaner.start }
  config.after { DatabaseCleaner.clean }
end
