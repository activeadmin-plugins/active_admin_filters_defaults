# active_admin_filters_defaults

Default values for Active Admin index filters.

Some index pages are not "a list you may want to narrow down", they are "a list that is only
meaningful, or only affordable, inside a window": a log table partitioned by date, a page backed
by an external service that will not answer an unbounded query, a queue an agent should land on.
Active Admin has no way to say so, so every app of this size grows a `before_action` that mutates
`params[:q]`. This is that, as an option on the filter itself.

```ruby
ActiveAdmin.register Order do
  filter :state_eq, as: :select, collection: %w[pending paid], default: "pending"
end
```

## Install

```ruby
gem "active_admin_filters_defaults", github: "activeadmin-plugins/active_admin_filters_defaults"
```

Pre-1.0 and not on RubyGems yet: the option name and the shape of its value may still change.

## Usage

**A scalar** applies to the filter name as it stands, which is what a name that already carries
its predicate needs:

```ruby
filter :state_eq, as: :select, collection: %w[active archived], default: "active"
```

**A Hash** is keyed by predicate, for inputs that render more than one field. A `:date_range`
renders a `gteq` and an `lteq` field, and a `:check_boxes` submits as `q[author_id_in][]`, so the
filter name on its own does not identify a search key:

```ruby
filter :created_at, as: :date_range,  default: { gteq: -> { 1.week.ago.to_date } }
filter :author,     as: :check_boxes, default: { id_in: [1, 2] }
```

**A Proc** is evaluated against the controller on every request, and a `nil` result applies no
filter, which is how a default is made conditional or read off the signed-in admin:

```ruby
filter :author_id_eq, default: -> { current_admin_user.id unless current_admin_user.admin? }
filter :queue_eq,     default: -> { current_admin_user.default_queue }
```

A filter hidden by `:if` or `:unless` imposes no default either — it would filter the collection
with no control on screen to undo it.

## Getting out of a default

Defaults apply only while the request carries no filters of its own.

* The default also seeds the visible form, so the admin can see why the list is filtered and edit
  that value like any other filter.
* **Blank the field and press Filter** to see the unfiltered collection. Active Admin disables
  empty fields on submit, so a blank submission sends no `q` at all and is told apart from a first
  visit by `commit`.
* **Clear Filters** drops `commit` along with `q`, so it returns the page to its defaults rather
  than to an empty filter set.

## Widening when the defaults apply

By default they apply to a request that carries no filters of its own. A resource that always
carries something in `q` — a customer id pinned by a nested route, say — can widen that:

```ruby
controller do
  def filter_defaults_apply?
    super || params[:q].keys == %w[customer_id_eq]
  end
end
```

Whatever the request asked for wins over a default, so the pinned value survives.

## Telling the admin why

An index that quietly shows a slice of the table owes the admin a word about it. That part is
optional and is not installed on its own, since Active Admin has no notion of a flash about
filters:

```ruby
# config/initializers/active_admin.rb
require "active_admin_filters_defaults/notice"

ActiveAdmin.register Export do
  default_filters_notice "Records for the last month are displayed by default"
  filter :created_at, as: :date_range, default: { gteq: -> { 1.month.ago } }
end
```

The message is flashed only when the defaults actually took effect. Pass `flash_key:` to use
something other than `:notice`.

## How it works

Four `prepend`s, no source patching:

* `ActiveAdmin::ResourceController` — `apply_filtering` searches on `filtering_params`, a new
  overridable method, instead of reading `params[:q]` directly. `params` itself is never written
  to: the filter inputs read their value from the Ransack object, and the defaults are derived
  again on every request that carries no `q`, so paging, sorting and download links keep them.
* `ActiveAdmin::Resource` — the filters sidebar is handed the filters that `:if` and `:unless`
  allow, so the same set is rendered and consulted for defaults, and the conditions are resolved
  once rather than once per side.
* `ActiveAdmin::Filters::ViewHelper` — the form renders what it is given, and `:default` is taken
  out of the options before Formtastic sees them.
* `ActiveAdmin::Filters::ActiveSidebar` — the Current Filters panel was gated on `params[:q]`,
  which stays empty when the values came from `default:`, so it now also shows for those.

`default:` needs no registration of its own: `add_filter` stores whatever options it is given,
without a whitelist.

Tested against Active Admin 3.5 on Rails 7.2 and 8.0.

## License

MIT
