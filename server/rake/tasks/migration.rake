require 'active_record'

namespace :migration do
  def exec_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  desc 'db/migrate/timestamp_*.rb not in schema_migrations'
  task diff: :environment do
    migrate_path = File.join(ENV['APP_ROOT_PATH'], 'db/migrate/')
    timestamps = []
    Dir.entries(migrate_path).each do |migrate|
      next if migrate == '.' || migrate == '..'

      timestamp = migrate.split('_')[0]
      timestamps.push(timestamp)
    end

    versions = exec_sql('select version from schema_migrations;').map(&:first)

    puts 'migrate not in schema_migrations:'
    puts timestamps - versions
    (timestamps - versions).each do |version|
      puts "insert into schema_migrations(version) value('#{version}');"
    end
    puts '-' * 10
    puts 'schema_migrations not in migrate:'
    puts versions - timestamps
  end
end
