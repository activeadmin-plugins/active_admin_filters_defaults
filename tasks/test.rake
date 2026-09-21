# frozen_string_literal: true

desc "Creates a test rails app for the specs to run against"
task :setup do
  require "rails/version"

  args = %w[
    --skip-spring
    --skip-bootsnap
    --skip-test
    --skip-system-test
    -m spec/support/rails_template.rb
  ].join(" ")

  system "bundle exec rails new spec/rails/rails-#{Rails::VERSION::STRING} #{args}"
end
