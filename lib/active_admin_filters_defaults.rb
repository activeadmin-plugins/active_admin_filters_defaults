# frozen_string_literal: true

require "activeadmin"
require "active_admin_filters_defaults/version"
require "active_admin_filters_defaults/data_access"
require "active_admin_filters_defaults/filter_defaults"
require "active_admin_filters_defaults/filters_form"
require "active_admin_filters_defaults/mode"

module ActiveAdminFiltersDefaults
end

# The mode falls back application -> namespace -> resource; registering on NamespaceSettings
# is what joins that chain. :redirect is the default on purpose - a URL that means the page.
ActiveAdmin::NamespaceSettings.register :filter_defaults_mode, :redirect

# `add_filter` stores whatever options it is given without a whitelist, so `default:` needs no
# registration of its own.
ActiveAdmin.before_load do |_app|
  # Prepended, because it replaces Active Admin's own #apply_filtering.
  ActiveAdmin::ResourceController.prepend ActiveAdminFiltersDefaults::DataAccess
  # Included, because it only adds - and a resource overriding one of its seams in a
  # `controller do` block should win, which is what including gives.
  ActiveAdmin::ResourceController.include ActiveAdminFiltersDefaults::FilterDefaults
  ActiveAdmin::ResourceController.helper_method :filter_default_values, :visible_filters

  ActiveAdmin::Resource.prepend ActiveAdminFiltersDefaults::ResourceExtension
  ActiveAdmin::Resource.include ActiveAdminFiltersDefaults::ModeResource
  ActiveAdmin::ResourceDSL.include ActiveAdminFiltersDefaults::ModeDSL
  ActiveAdmin::ResourceController.include ActiveAdminFiltersDefaults::RedirectMode
  ActiveAdmin::Filters::ViewHelper.prepend ActiveAdminFiltersDefaults::ViewHelper
  ActiveAdmin::Filters::ActiveSidebar.prepend ActiveAdminFiltersDefaults::ActiveSidebar
end
