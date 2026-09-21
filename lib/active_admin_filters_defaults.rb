# frozen_string_literal: true

require "activeadmin"
require "active_admin_filters_defaults/version"
require "active_admin_filters_defaults/data_access"
require "active_admin_filters_defaults/filters_form"

module ActiveAdminFiltersDefaults
end

# `add_filter` stores whatever options it is given without a whitelist, so `default:` needs no
# registration of its own.
ActiveAdmin.before_load do |_app|
  ActiveAdmin::ResourceController.prepend ActiveAdminFiltersDefaults::DataAccess
  ActiveAdmin::ResourceController.helper_method :filter_default_values, :visible_filters

  ActiveAdmin::Resource.prepend ActiveAdminFiltersDefaults::ResourceExtension
  ActiveAdmin::Filters::ViewHelper.prepend ActiveAdminFiltersDefaults::ViewHelper
  ActiveAdmin::Filters::ActiveSidebar.prepend ActiveAdminFiltersDefaults::ActiveSidebar
end
