# frozen_string_literal: true

desc "Creates a test rails app for the specs to run against"
task :setup do
  require "rails/version"
  mode = ENV["APP_MODE"]
  abort "APP_MODE=redirect or APP_MODE=implicit is required - one sample app per filter_defaults_mode" unless %w[redirect implicit].include?(mode)

  args = %w[
    --skip-spring
    --skip-bootsnap
    --skip-test
    --skip-system-test
    -m spec/support/rails_template.rb
  ].join(" ")

  system "bundle exec rails new spec/rails/rails-#{Rails::VERSION::STRING}-#{mode} #{args}"
end
