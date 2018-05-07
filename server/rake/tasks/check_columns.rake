# encoding: utf-8

def add_column_id(table_name)
  <<-EOF.strip_heredoc
    ALTER TABLE `#{table_name}`
    ADD COLUMN `id` integer NOT NULL AUTO_INCREMENT FIRST,
    ADD PRIMARY KEY(`id`);
  EOF
end

def check_column_created_at(table_name, is_exist = false)
  <<-EOF.strip_heredoc
    ALTER TABLE `#{table_name}`
    #{is_exist ? 'CHANGE `created_at`' : 'ADD COLUMN'} `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP;
  EOF
end

def check_column_updated_at(table_name, is_exist = false)
  <<-EOF.strip_heredoc
    ALTER TABLE `#{table_name}`
    #{is_exist ? 'CHANGE `updated_at`' : 'ADD COLUMN'}  `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
  EOF
end

def add_column_created_at2(table_name)
  <<-EOF.strip_heredoc
    ALTER TABLE `#{table_name}`
    ADD COLUMN `created_at` DATETIME;
  EOF
end

def add_column_updated_at2(table_name)
  <<-EOF.strip_heredoc
    ALTER TABLE `#{table_name}`
    ADD COLUMN `updated_at` DATETIME ;
  EOF
end

def drop_column(table_name, column_name)
  <<-EOF.strip_heredoc
    ALTER TABLE `#{table_name}`
    DROP COLUMN `#{column_name}`;
  EOF
end

def drop_primary_key(table_name)
  %(ALTER TABLE `#{table_name}` DROP PRIMARY KEY;)
end

def change_columns(connection, table_name, uninclude_columns)
  # connection.execute(add_column_id(table_name)) if uninclude_columns.include?('id')
  puts check_column_created_at(table_name, !uninclude_columns.include?('created_at'))
  connection.execute(check_column_created_at(table_name, !uninclude_columns.include?('created_at')))
  connection.execute(check_column_updated_at(table_name, !uninclude_columns.include?('updated_at')))
end

desc 'list tables that without column id(primary key)'
task check_columns: :environment do
  necessary_columns = %w(created_at updated_at)

  connection = ActiveRecord::Base.connection
  connection.tables.each do |table_name|
    uninclude_columns = necessary_columns - connection.columns(table_name).map(&:name)

    # puts table_name
    # begin
    change_columns(connection, table_name, uninclude_columns)
    # rescue => e
    #   puts e.message
    #   connection.execute(drop_primary_key(table_name))
    # end

    if uninclude_columns.empty?
      puts 'change created_at, updated_at successfully'
    else
      uninclude_columns = necessary_columns - connection.columns(table_name)
      puts %(no #{uninclude_columns.join(',')}, add column #{uninclude_columns.empty? ? 'failed' : 'successfully'}\n\n)
    end
  end
end

desc 'input exist template json content'
task template_report_seeds: :environment do
  template_path = File.join(ENV['APP_ROOT_PATH'], 'lib/templates/template_1_*')
  Dir.glob(template_path).each do |path|
    report_id = path.scan(/template_1_report_(\d)\.json/).flatten[0]

    Report.create(template_id: 1, report_id: report_id, content: IO.read(path), created_at: Time.now, updated_at: Time.now)
  end
end
