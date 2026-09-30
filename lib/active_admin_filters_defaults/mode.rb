# frozen_string_literal: true

module ActiveAdminFiltersDefaults
  # How the declared defaults meet the request. Two modes:
  #
  # :redirect (the default) - a URL that means the page. A bare HTML GET of the index
  # redirects once to itself with the effective filters spelled out in the query string, so
  # the address the admin copies carries the same window, the same values, for whoever opens
  # it: a relative default is frozen to the dates it came to, a per-admin default to the
  # values this admin saw. The price: +1 redirect on every bare visit, and a bookmarked URL
  # pins the defaults of the day it was made rather than following the code.
  #
  # :implicit - the request stays exactly what the admin asked. The defaults live in the
  # search and the filter form only; the URL never mentions them. Nothing extra in the
  # address bar and no extra hop - but a copied bare URL re-resolves the defaults against
  # the recipient's clock and account, and anything built from `params[:q]` (drill-down
  # links, exports, saved searches) must read #filtering_params instead to see them.
  #
  # The mode inherits the way Active Admin settings do - application, then namespace, then
  # resource - because how an admin treats its URLs is usually a property of the whole admin:
  #
  #   ActiveAdmin.setup do |config|
  #     config.filter_defaults_mode = :implicit          # the whole application
  #     config.namespace :support do |support|
  #       support.filter_defaults_mode = :redirect       # one namespace
  #     end
  #   end
  #
  #   ActiveAdmin.register Cdr do
  #     filter_defaults_mode :implicit                   # one resource
  #   end
  MODES = %i[redirect implicit].freeze

  module ModeDSL
    def filter_defaults_mode(value)
      config.filter_defaults_mode = value
    end
  end

  # The breadcrumb pattern: a resource answers for itself when it has been told, and asks its
  # namespace otherwise - which in turn falls back to the application through the settings
  # chain the register call below joins.
  module ModeResource
    attr_writer :filter_defaults_mode

    def filter_defaults_mode
      if instance_variable_defined?(:@filter_defaults_mode)
        @filter_defaults_mode
      else
        namespace.filter_defaults_mode
      end
    end
  end

  module RedirectMode
    def self.included(base)
      base.before_action only: :index do
        mode = active_admin_config.filter_defaults_mode
        unless MODES.include?(mode)
          raise ArgumentError,
                "filter_defaults_mode is #{mode.inspect}, must be one of #{MODES.map(&:inspect).join(', ')}"
        end
        next unless mode == :redirect

        # Only where an address bar is watching. The defaults themselves do not depend on the
        # redirect - #filtering_params applies them to a CSV or JSON index all the same - so a
        # non-HTML request just keeps its one-request shape.
        next unless request.get? && request.format.html?

        effective = filtering_params
        effective = effective.to_unsafe_h if effective.respond_to?(:to_unsafe_h)
        requested = params[:q]
        requested = requested.to_unsafe_h if requested.respond_to?(:to_unsafe_h)
        # `?q=` parses to an empty String; treat it the way #filtering_params does - as absent -
        # so the equality below compares Hashes on both sides.
        requested = nil unless requested.is_a?(Hash)

        # An empty Array is a value to_query drops from the URL entirely - redirecting on it
        # would loop, since the redirected URL parses back without the key and the next request
        # is bare again. A value the URL cannot say stays on the implicit path.
        effective = effective.reject { |_, value| value.is_a?(Array) && value.empty? }

        # One redirect, not a loop, whatever #filter_defaults_apply? has been widened to: once
        # the query string carries everything the defaults would add, the two sides are equal
        # and the request passes through. This also covers "defaults do not apply here" -
        # #filtering_params answers with the request's own `q` and equality holds.
        next if effective.blank? || effective == (requested || {})

        # This request is the one a declared notice belongs on, and it is about to answer 302 -
        # a flash.now would die with it, so the message rides the redirect instead. Guarded by
        # respond_to?: the notice is its own opt-in require and may not be loaded.
        if active_admin_config.respond_to?(:default_filters_notice) &&
           (message = active_admin_config.default_filters_notice)
          # An untouched flash rides the hop on its own - Rails only sweeps what a request has
          # loaded - but writing the notice loads it, and everything that arrived with the
          # request (a batch action's "n records done") would be swept with the 302. Keep it:
          # those messages are addressed to the page this redirect is on the way to.
          flash.keep
          flash[active_admin_config.default_filters_notice_flash_key] =
            ::MethodOrProcHelper.render_in_context(self, message)
        end

        redirect_to "#{request.path}?#{request.query_parameters.merge('q' => effective).to_query}"
      end
    end
  end
end
