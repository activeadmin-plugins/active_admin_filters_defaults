# frozen_string_literal: true

require "capybara/cuprite"

Capybara.server = :webrick
Capybara.register_driver :cuprite do |app|
  # Ferrum waits 10 seconds by default for Chrome to report its websocket URL, which a cold CI
  # runner does not always manage.
  Capybara::Cuprite::Driver.new(app, headless: true, window_size: [1280, 800], process_timeout: 60)
end
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 5
