require 'active_record'

RSpec.configure do |config|
  
  db_config = {
    adapter: :sqlite3,
    database: ':memory:'
  }

  config.before :suite do
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::MigrationContext.new('spec/support/migrations', ActiveRecord::Base.connection.schema_migration).migrate
  end
end
