# frozen_string_literal: true

require "active_admin_filters_defaults"

module ActiveAdminFiltersDefaults
  # Optional, and a deliberate departure from the gem's usual manner: everywhere else the
  # defaults stay out of the request, here the request is rewritten to spell them out.
  # Require it explicitly to switch it on.
  #
  #   # config/initializers/active_admin.rb
  #   require "active_admin_filters_defaults/redirect"
  #
  # What it buys is a URL that means the page: a bare visit to the index redirects once to
  # itself with the effective filters in the query string, so the address the admin copies
  # carries the same window, the same values, for whoever opens it - a relative default is
  # frozen to the dates it came to, a per-admin default to the values this admin saw. Without
  # it a shared bare URL re-resolves the defaults against the recipient's clock and account.
  #
  # The price is the mirror image: +1 redirect on every bare visit, and a bookmarked URL pins
  # the defaults of the day it was made rather than following the code.
  #
  # The switch inherits the way Active Admin settings do - application, then namespace, then
  # resource - because "our pages get shared around" is usually true of a whole admin, not of
  # one index:
  #
  #   ActiveAdmin.setup do |config|
  #     config.redirect_to_default_filters = true            # everywhere
  #     config.namespace :support do |support|
  #       support.redirect_to_default_filters = true         # one namespace
  #     end
  #   end
  #
  #   ActiveAdmin.register Cdr do
  #     redirect_to_default_filters                          # one resource
  #     # or, amid a namespace that switched it on:
  #     config.redirect_to_default_filters = false
  #   end
  module Redirect
    def redirect_to_default_filters
      config.redirect_to_default_filters = true
    end
  end

  # The breadcrumb pattern: a resource answers for itself when it has been told, and asks its
  # namespace otherwise - which in turn falls back to the application through the settings
  # chain the register call below joins.
  module RedirectResource
    attr_writer :redirect_to_default_filters

    def redirect_to_default_filters
      if instance_variable_defined?(:@redirect_to_default_filters)
        @redirect_to_default_filters
      else
        namespace.redirect_to_default_filters
      end
    end
  end

  module RedirectController
    def self.included(base)
      base.before_action only: :index do
        next unless active_admin_config.redirect_to_default_filters

        # Only where an address bar is watching. The defaults themselves do not depend on the
        # redirect - #filtering_params applies them to a CSV or JSON index all the same - so a
        # non-HTML request just keeps its one-request shape.
        next unless request.get? && request.format.html?

        effective = filtering_params
        effective = effective.to_unsafe_h if effective.respond_to?(:to_unsafe_h)
        requested = params[:q]
        requested = requested.to_unsafe_h if requested.respond_to?(:to_unsafe_h)

        # One redirect, not a loop, whatever #filter_defaults_apply? has been widened to: once
        # the query string carries everything the defaults would add, the two sides are equal
        # and the request passes through. This also covers "defaults do not apply here" -
        # #filtering_params answers with the request's own `q` and equality holds.
        next if effective.blank? || effective == (requested || {})

        redirect_to "#{request.path}?#{request.query_parameters.merge('q' => effective).to_query}"
      end
    end
  end
end

# Registered at require time, before the initializer block below it gets to name the setting
# on a namespace. Off by default: the redirect is the opt-in side of a trade.
ActiveAdmin::NamespaceSettings.register :redirect_to_default_filters, false

ActiveAdmin.before_load do |_app|
  ActiveAdmin::ResourceDSL.include ActiveAdminFiltersDefaults::Redirect
  ActiveAdmin::Resource.include ActiveAdminFiltersDefaults::RedirectResource
  ActiveAdmin::ResourceController.include ActiveAdminFiltersDefaults::RedirectController
end
