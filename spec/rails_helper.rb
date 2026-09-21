# frozen_string_literal: true

# Boots the generated sample app. Only the integration specs need this - the unit specs run
# against a stand-in controller and stay in spec_helper.

$LOAD_PATH.unshift(File.expand_path("support", __dir__))

ENV["BUNDLE_GEMFILE"] = File.expand_path("../Gemfile", __dir__)
require "bundler"
Bundler.setup

ENV["RAILS_ENV"] = "test"
require "rails"
ENV["RAILS"] = Rails.version
ENV["RAILS_ROOT"] = File.expand_path("rails/rails-#{ENV['RAILS']}", __dir__)

system "rake setup" unless File.exist?(ENV["RAILS_ROOT"])

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
