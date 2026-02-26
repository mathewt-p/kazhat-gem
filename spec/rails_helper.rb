ENV["RAILS_ENV"] = "test"

require File.expand_path("dummy/config/environment", __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "factory_bot_rails"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

# Load dummy schema + kazhat migrations in test DB
ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

# Run kazhat migrations
kazhat_migration_path = File.expand_path("../db/migrate", __dir__)
ActiveRecord::MigrationContext.new(kazhat_migration_path).migrate

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    Kazhat.reset_configuration!
    Kazhat.configure do |c|
      c.user_class = "User"
      c.current_user_method = :current_user
    end
  end

  config.after(:each) do
    Kazhat.reset_configuration!
    Kazhat.configure do |c|
      c.user_class = "User"
      c.current_user_method = :current_user
    end
  end
end
