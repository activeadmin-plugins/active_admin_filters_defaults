# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/hash_with_indifferent_access"
# Pure Ruby, no Active Admin boot required - `visible_filters` resolves `:if` / `:unless` with it.
require "active_admin/view_helpers/method_or_proc_helper"
require "active_admin_filters_defaults/data_access"

# `DataAccess` only needs `params`, `active_admin_config` and something that answers `ransack`.
# That lets the unit suite run without booting Active Admin or Rails; the integration suite in
# spec/integration exercises the real thing.
class FakeChain
  attr_reader :ransacked_with

  def ransack(params)
    @ransacked_with = params
    self
  end

  def result
    self
  end
end

class FakeController
  Config = Struct.new(:filters)

  attr_reader :params, :active_admin_config

  def initialize(params: {}, filters: {})
    @params = ActiveSupport::HashWithIndifferentAccess.new(params)
    @active_admin_config = Config.new(filters)
  end

  prepend ActiveAdminFiltersDefaults::DataAccess
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
