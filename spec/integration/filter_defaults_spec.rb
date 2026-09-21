# frozen_string_literal: true

require "rails_helper"

# The sample app registers Post once per filter input type - see spec/support/rails_template.rb.
# Every default below selects `keep me` and rejects `drop me`, so one pair of records exercises
# all of them.
RSpec.describe "Filter default values", type: :feature do
  before do
    AdminUser.create!(email: "admin@example.com", default_status: "published")

    Post.create!(title: "keep me", body: "keep body", status: "published",
                 position: 20, published_date: Date.new(2026, 6, 1), starred: true)
    Post.create!(title: "drop me", body: "drop body", status: "draft",
                 position: 1, published_date: Date.new(2020, 1, 1), starred: false)
  end

  describe "every filter input type" do
    {
      "string, predicate in the Hash key" => "/admin/posts",
      "string, predicate already in the filter name" => "/admin/scalar_posts",
      "numeric" => "/admin/numeric_posts",
      "date range" => "/admin/date_posts",
      "select" => "/admin/select_posts",
      "check boxes" => "/admin/check_boxes_posts",
      "boolean" => "/admin/boolean_posts"
    }.each do |input_type, path|
      it "applies the declared default to a #{input_type} filter" do
        visit path

        expect(page).to have_content("keep me")
        expect(page).to have_no_content("drop me")
      end
    end
  end

  describe "a value that cannot be placed" do
    it "says so instead of guessing" do
      expect { visit "/admin/ambiguous_posts" }
        .to raise_error(ArgumentError, /filter :published_date declares a `default:`.*single value cannot say which to fill/m)
    end
  end

  describe "the form the admin sees" do
    it "is seeded with the default, so it can be read and edited like any other filter" do
      visit "/admin/posts"

      expect(page).to have_field("q[title_cont]", with: "keep")
    end

    it "shows everything once the field is blanked and the form submitted" do
      visit "/admin/posts"
      fill_in "q[title_cont]", with: ""
      click_button "Filter"

      expect(page).to have_content("keep me")
      expect(page).to have_content("drop me")
    end

    it "leaves a resource that declares no default alone" do
      visit "/admin/plain_posts"

      expect(page).to have_content("keep me")
      expect(page).to have_content("drop me")
    end
  end

  describe ":if and :unless" do
    it "neither renders a denied filter nor lets it impose its default" do
      visit "/admin/conditional_posts"

      # `title` is denied by `:if`, `body` by `:unless`: their inputs are gone, and their
      # defaults are not in force either - `drop me` is excluded by the `status` filter alone.
      expect(page).to have_no_field("q[title_cont]")
      expect(page).to have_no_field("q[body_cont]")
      expect(page).to have_field("q[status_eq]")
    end

    it "renders the index when every filter of the resource is denied" do
      visit "/admin/all_hidden_posts"

      expect(page).to have_content("keep me")
      expect(page).to have_content("drop me")
    end

    it "applies the default of the filter its condition allows" do
      visit "/admin/conditional_posts"

      expect(page).to have_content("keep me")
      expect(page).to have_no_content("drop me")
    end
  end

  describe "a default read off the signed in admin" do
    it "filters on what the admin saved" do
      visit "/admin/admin_preference_posts"

      expect(page).to have_content("keep me")
      expect(page).to have_no_content("drop me")
    end

    it "applies no filter when the admin saved nothing" do
      AdminUser.update_all(default_status: nil)

      visit "/admin/admin_preference_posts"

      expect(page).to have_content("keep me")
      expect(page).to have_content("drop me")
    end
  end

  describe "default_filters_notice" do
    it "tells the admin why the list is cut down" do
      visit "/admin/notice_posts"

      expect(page).to have_content("Showing the kept ones by default")
    end

    it "stays quiet once the admin has filtered for themselves" do
      visit "/admin/notice_posts"
      fill_in "q[title_cont]", with: "drop"
      click_button "Filter"

      expect(page).to have_no_content("Showing the kept ones by default")
    end
  end

  describe "requests that carry no q of their own" do
    it "keeps the default while paging" do
      visit "/admin/posts?page=1"

      expect(page).to have_no_content("drop me")
    end

    # The download link is built from params, which carry no `q` while the index is showing its
    # declared defaults, so the CSV request has to derive them again to match the screen.
    it "exports the filtered collection to CSV, not the whole table" do
      visit "/admin/posts"
      click_link "CSV"

      expect(page.body).to include("keep me")
      expect(page.body).to_not include("drop me")
    end
  end

  # Clear Filters strips `q[`, `page`, `utf8` and `commit` from the query string, which is the
  # state a first visit is in, so it returns the page to its declared defaults rather than to an
  # empty filter set.
  it "returns to the defaults after Clear Filters", :js do
    visit "/admin/posts"
    fill_in "q[title_cont]", with: ""
    click_button "Filter"
    expect(page).to have_content("drop me")

    click_link "Clear Filters"

    expect(page).to have_content("keep me")
    expect(page).to have_no_content("drop me")
  end
end
