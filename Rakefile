# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

Dir["tasks/**/*.rake"].each { |task| load task }

RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern = "spec/*_spec.rb"
end

# The integration suites boot different sample apps - one per filter_defaults_mode - so each
# runs as its own process against its own app.
desc "Run the integration suite of each filter_defaults_mode against its own sample app"
task :integration do
  %w[redirect implicit].each do |mode|
    sh({ "APP_MODE" => mode }, "bundle exec rspec spec/integration/#{mode}")
  end
end

task spec: %i[unit integration]
task default: :spec
