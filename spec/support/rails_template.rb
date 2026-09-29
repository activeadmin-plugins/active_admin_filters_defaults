# frozen_string_literal: true

# Rails template that builds the sample app the specs run against.

# Rails 8 no longer generates a Sprockets manifest, and Active Admin 3 needs one.
FileUtils.mkdir_p("app/assets/config")
File.write("app/assets/config/manifest.js", "//= link_tree ../images\n")

# One column per filter input type, so every input can be exercised against a real index.
generate :model,
         "post title:string body:text status:string position:integer " \
         "published_date:date starred:boolean --force"

inject_into_file "app/models/post.rb",
                 "  def self.ransackable_attributes(auth_object = nil)\n" \
                 "    %w[title body status position published_date starred]\n" \
                 "  end\n" \
                 "  def self.ransackable_associations(auth_object = nil)\n" \
                 "    []\n" \
                 "  end\n",
                 after: "ApplicationRecord\n"

# Stands in for the signed-in admin carrying their own saved filter preset. Devise is out of the
# picture - the specs disable authentication - so `current_admin_user` is defined by hand below.
generate :model, "admin_user email:string default_status:string --force"

# Put the gem under test on the load path of the generated app.
gem_lib = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "lib"))
gsub_file "config/environment.rb",
          'require_relative "application"',
          "require_relative \"application\"\n" \
          "$LOAD_PATH.unshift('#{gem_lib}')\n" \
          "require \"active_admin_filters_defaults\"\n"

file "config/initializers/filters_defaults_notice.rb", <<~RUBY
  require "active_admin_filters_defaults/notice"
RUBY

file "config/initializers/filters_defaults_redirect.rb", <<~RUBY
  require "active_admin_filters_defaults/redirect"

  # The :sharing namespace turns the redirect on wholesale; its resources are registered without
  # a word about it. The :admin namespace stays on the application default (off), so the
  # per-resource DSL is what the RedirectPost specs exercise.
  ActiveAdmin.setup do |config|
    config.namespace :sharing do |sharing|
      sharing.redirect_to_default_filters = true
    end
  end
RUBY

generate :"active_admin:install --skip-users"
generate :"formtastic:install"

file "config/initializers/current_admin_user.rb", <<~RUBY
  # No Devise here: the specs disable Active Admin authentication and this is all
  # `default: -> { current_admin_user... }` needs to resolve.
  ActiveAdmin.before_load do
    ActiveAdmin::BaseController.class_eval do
      def current_admin_user
        AdminUser.first
      end
      helper_method :current_admin_user
    end
  end
RUBY

# One registration per filter input type. They have to be separate resources: a single index
# carrying every default at once would filter itself down to nothing.
#
# Only a filter name that already carries its predicate takes a scalar - see ScalarPost. For
# everything else the predicate belongs in the Hash key, because the input decides the search
# key: `:numeric` submits `_eq` / `_gt` / `_lt`, `:date_range` submits `_gteq` and `_lteq`,
# `:check_boxes` submits `_in[]`.
file "app/admin/posts.rb", <<~RUBY
  ActiveAdmin.register Post do
    filter :title, default: "keep"

    csv do
      column :title
    end
  end

  ActiveAdmin.register Post, as: "ScalarPost" do
    filter :title_cont, as: :string, default: "keep"
  end

  ActiveAdmin.register Post, as: "NumericPost" do
    filter :position, as: :numeric, default: { gt: 10 }
  end

  ActiveAdmin.register Post, as: "DatePost" do
    filter :published_date, as: :date_range, default: Date.new(2026, 1, 1)..
  end

  ActiveAdmin.register Post, as: "SelectPost" do
    filter :status, as: :select, collection: %w[draft published], default: "published"
  end

  ActiveAdmin.register Post, as: "CheckBoxesPost" do
    filter :status, as: :check_boxes, collection: %w[draft published], default: ["published"]
  end

  ActiveAdmin.register Post, as: "BooleanPost" do
    filter :starred, default: true
  end

  ActiveAdmin.register Post, as: "AdminPreferencePost" do
    filter :status_eq, as: :select, collection: %w[draft published],
                       default: -> { current_admin_user.default_status }
  end

  ActiveAdmin.register Post, as: "ConditionalPost" do
    filter :title, default: "keep", if: -> { false }
    filter :body, default: "keep", unless: -> { true }
    filter :status, as: :select, collection: %w[draft published],
                    default: "published", if: -> { true }
  end

  ActiveAdmin.register Post, as: "PlainPost" do
    filter :title
  end

  ActiveAdmin.register Post, as: "NoticePost" do
    default_filters_notice "Showing the kept ones by default"
    filter :title, default: "keep"
  end

  ActiveAdmin.register Post, as: "AmbiguousPost" do
    filter :published_date, as: :date_range, default: Date.new(2026, 1, 1)
  end

  ActiveAdmin.register Post, as: "ProcInputHtmlPost" do
    filter :status, as: :select, collection: %w[draft published],
                    input_html: proc { { class: "select2" } }, default: "published"
  end

  ActiveAdmin.register Post, as: "AllHiddenPost" do
    filter :title, if: -> { false }
  end

  ActiveAdmin.register Post, as: "RedirectPost" do
    redirect_to_default_filters

    filter :status, as: :select, collection: %w[draft published], default: "published"
    filter :published_date, as: :date_range, default: -> { Date.new(2026, 1, 1).. }

    csv do
      column :title
    end
  end

  ActiveAdmin.register Post, as: "RedirectNoDefaultsPost" do
    redirect_to_default_filters

    filter :title
  end

  ActiveAdmin.register Post, as: "SharedPost", namespace: :sharing do
    filter :status, as: :select, collection: %w[draft published], default: "published"

    # Stands in for any action that flashes and sends the admin back to the index - a batch
    # action, a callback - whose flash must survive the index's own redirect.
    collection_action :poke do
      redirect_to collection_path, notice: "poked"
    end
  end

  ActiveAdmin.register Post, as: "QuietPost", namespace: :sharing do
    config.redirect_to_default_filters = false

    filter :status, as: :select, collection: %w[draft published], default: "published"
  end

  ActiveAdmin.register Post, as: "NoticeSharedPost", namespace: :sharing do
    # Its own flash key, the way an app keeps the filters notice from colliding with the
    # :notice a batch action or callback writes - both have to survive the redirect together.
    default_filters_notice "Showing published posts by default", flash_key: :filters_notice

    filter :status, as: :select, collection: %w[draft published], default: "published"

    collection_action :poke do
      redirect_to collection_path, notice: "poked"
    end
  end
RUBY

run "rm -rf test"
route "root to: 'admin/dashboard#index'"
rake "db:migrate"

# Removed last so the generators above still resolve their dependencies.
run "rm -f Gemfile Gemfile.lock"
