ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Rails.application.try(:reload_routes_unless_loaded)

module ActiveSupport
  class TestCase
    def create_user(name = "User", **attributes)
      user = User.new({ name: name, email: "#{name.parameterize}-#{SecureRandom.hex(3)}@example.com", password: "secret123" }.merge(attributes))
      user.skip_confirmation!
      user.save!
      user
    end

    def create_inventory(owner, **attributes)
      owner.inventories.create!({ title: "Laptops" }.merge(attributes))
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers

    def json
      JSON.parse(response.body)
    end

    def assert_translated
      assert_no_match(/translation[ _]missing/i, response.body)
    end
  end
end
