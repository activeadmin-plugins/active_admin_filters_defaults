# frozen_string_literal: true

module ActiveAdminFiltersDefaults
  # Everything `filter ..., default:` means: which requests the declared defaults apply to, what
  # they come to on this one, and which Ransack key each value lands under.
  #
  # Included rather than prepended - none of it replaces anything Active Admin defines, and a
  # resource is meant to be able to override the seams here in its own `controller do` block.
  # The one method that does replace Active Admin's is in DataAccess.
  module FilterDefaults
    protected

    # The filter values the collection is searched with. Override to change what the index
    # filters on without reaching into `params`.
    #
    # Whatever the request asked for wins over a default, so that an override of
    # #filter_defaults_apply? which lets defaults through on a partly filtered request keeps
    # the values that were actually asked for.
    #
    # @return [Hash, ActionController::Parameters] values passed to Ransack
    def filtering_params
      return params[:q] || {} unless filter_defaults_apply?

      defaults = filter_default_values
      return params[:q] || {} if defaults.blank?

      requested = params[:q]
      requested = requested.to_unsafe_h if requested.respond_to?(:to_unsafe_h)
      defaults.merge(requested || {})
    end

    # Whether the request is one the declared defaults should apply to. Override to widen it -
    # a resource that always carries its customer in `q`, say, still wants its defaults on the
    # first visit:
    #
    #   def filter_defaults_apply?
    #     super || params[:q].keys == %w[customer_id_eq]
    #   end
    #
    # `commit` marks a submission of the filters form: submitting it with every field blank
    # sends no `q` at all, because the form disables empty fields on submit, so `commit` is
    # what tells "show me everything" apart from a first visit. Clearing the filters drops
    # `commit` along with `q`, so Clear Filters returns the page to its declared defaults.
    def filter_defaults_apply?
      params[:q].blank? && params[:commit].blank?
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

        add_filter_default_value(result, attribute, options)
      end
    end

    private

    # A default is a value, and where that value goes is the input's business - see SearchKeys.
    #
    #   filter :status, as: :select,      default: "active"
    #   filter :author, as: :check_boxes, default: [1, 2]
    #   filter :created_at, as: :date_range, default: -> { 1.week.ago.. }
    #
    # A Hash still says the predicates outright, for when the input's own is not the one you
    # want (`default: { eq: "acme" }` on a string filter that would otherwise search `_cont`).
    #
    # Only a Proc is called - unlike `:if` and `:unless`, a Symbol here is a value, not a
    # method to send.
    def add_filter_default_value(result, attribute, options)
      default = options[:default]
      default = instance_exec(&default) if default.is_a?(Proc)
      return if default.nil?

      if default.is_a?(Hash)
        default.each do |predicate, value|
          value = instance_exec(&value) if value.is_a?(Proc)
          result["#{attribute}_#{predicate}"] = value unless value.nil?
        end
      else
        assign_derived_filter_default(result, attribute, options, default)
      end
    end
    # A Range fills a two-ended input, one bound per end, and an endless or beginless one fills
    # only the end it has. Anything else is a single value for a single-ended input.
    def assign_derived_filter_default(result, attribute, options, default)
      names = filter_search_keys(attribute, options)

      if default.is_a?(Range)
        unless names.size == 2
          raise_filter_default_error(attribute, "a Range needs an input with two ends, and this one submits #{names.join(' and ')}")
        end

        result[names.first] = default.begin unless default.begin.nil?
        result[names.last] = default.end unless default.end.nil?
      else
        unless names.size == 1
          raise_filter_default_error(attribute, "this input submits #{names.join(' and ')}, so a single value cannot say which to fill - give a Range, or name the predicates with a Hash")
        end

        result[names.first] = default
      end
    end

    # Asked against an empty search on purpose: `current_filter` otherwise answers with whatever
    # predicate the current request happens to carry, and a default is about the request that
    # carries none.
    #
    # @return [Array<String>] one key, or two for a range input
    def filter_search_keys(attribute, options)
      input = build_filter_input(attribute, options)

      names =
        if input.respond_to?(:gt_input_name)
          [input.gt_input_name, input.lt_input_name]
        elsif input.respond_to?(:current_filter) && !input.seems_searchable?
          # `:string` and `:numeric` let the admin pick the predicate from a dropdown, and the
          # head of that list is what an untouched form submits. Unless the filter name already
          # carries a predicate, in which case there is no dropdown - and asking anyway raises,
          # since `current_filter` would go looking for `title_eq_cont`.
          [input.current_filter]
        else
          [input.input_name]
        end

      names.map { |name| name.to_s[/\Aq\[([^\]]+)\]/, 1] || name.to_s }
    rescue StandardError => e
      raise_filter_default_error(attribute, "could not work out which search key it submits (#{e.class}: #{e.message}) - name the predicate with a Hash instead")
    end

    def build_filter_input(attribute, options)
      builder = filter_input_builder
      as = options[:as] || builder.send(:default_input_type, attribute)
      builder.send(:namespaced_input_class, as)
             .new(builder, builder.template, builder.object, :q, attribute, options.except(:default, :if, :unless))
    end

    # One per request rather than one per filter: #view_context builds a fresh view class every
    # time it is called, and every defaulted filter would pay for another one.
    def filter_input_builder
      @filter_input_builder ||= ::ActiveAdmin::Filters::FormBuilder.new(
        :q, active_admin_config.resource_class.ransack({}), view_context, {}
      )
    end

    def raise_filter_default_error(attribute, message)
      raise ArgumentError, "filter :#{attribute} declares a `default:` but #{message}"
    end
  end
end
