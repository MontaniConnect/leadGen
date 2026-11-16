ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/fetching_test_helper"
require_relative "support/scoring_test_helper"
require_relative "support/drafting_test_helper"
require_relative "support/leads_test_helper"
require_relative "support/xlsx_reader"
require_relative "support/outreach_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Paid calls are blocked without a cap (fail closed), so tests run under a generous one.
    # Tests of the cap itself override it.
    setup { Setting.set("budget.spending_cap_usd", 1000) }

    # Add more helper methods to be used by all tests here...
  end
end
