# frozen_string_literal: true

module ActiveAdminFiltersDefaults
  # Replaces ActiveAdmin::ResourceController::DataAccess#apply_filtering so that the collection
  # is searched on #filter_params rather than on `params[:q]` read directly.
  #
  # The Ransack call is the Active Admin 3 one, which this gem targets: Active Admin 4 passes
  # `auth_object: active_admin_authorization` there as well.
  module DataAccess
    protected

    def apply_filtering(chain)
      @search = chain.ransack(filter_params)
      @search.result
    end

    # The filter values the collection is searched with. Override to change what the index
    # filters on without reaching into `params`.
    #
    # When the request carries no filters of its own, the values declared with
    # `filter ..., default:` are used. `commit` marks a submission of the filter form:
    # submitting it with every field blank sends no `q` at all, because the form disables
    # empty fields on submit, so `commit` is what tells "show me everything" apart from a
    # first visit. Clearing the filters drops `commit` along with `q`, so Clear Filters
    # returns the page to its declared defaults.
    #
    # @return [Hash, ActionController::Parameters] values passed to Ransack
    def filter_params
      return params[:q] || {} if params[:q].present? || params[:commit].present?

      filter_default_values.presence || params[:q] || {}
    end

    # The filters of this resource that `:if` and `:unless` allow, which is both the set the
    # filters form renders and the set that can impose a default - a filter that is not
    # rendered does not filter the collection behind the admin's back.
    #
    # @return [Hash] filter attribute => filter options
    def visible_filters
      @visible_filters ||= active_admin_config.filters.reject do |_attribute, options|
        (options.key?(:if) && !::MethodOrProcHelper.render_in_context(self, options[:if])) ||
          (options.key?(:unless) && ::MethodOrProcHelper.render_in_context(self, options[:unless]))
      end
    end

    # @return [Hash] the search values declared with `filter ..., default:`
    def filter_default_values
      @filter_default_values ||= visible_filters.each_with_object({}) do |(attribute, options), result|
        next unless options.key?(:default)

        add_filter_default_value(result, attribute, options[:default])
      end
    end

    # A scalar default applies to the filter name as it stands, which is what filters whose
    # name already carries a predicate need: `filter :status_eq, default: "active"`.
    #
    # A Hash is keyed by predicate, which is what an input rendering more than one field
    # needs, since the filter name alone does not identify a search key:
    # `filter :created_at, as: :date_range, default: { gteq: -> { 1.week.ago.to_date } }`.
    #
    # Only a Proc is called - unlike `:if` and `:unless`, a Symbol here is a value, not a
    # method to send.
    def add_filter_default_value(result, attribute, default)
      default = instance_exec(&default) if default.is_a?(Proc)
      return if default.nil?

      if default.is_a?(Hash)
        default.each do |predicate, value|
          value = instance_exec(&value) if value.is_a?(Proc)
          result["#{attribute}_#{predicate}"] = value unless value.nil?
        end
      else
        result[attribute.to_s] = default
      end
    end
  end
end
