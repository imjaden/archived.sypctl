require 'json'
require 'mysql2'

config = {
  "host": "121.199.38.185",
  "port": "3700",
  "username": "root_name",
  "password": "!QAZ2wsx",
  "database": "eziiot_db62"
}

client = Mysql2::Client.new(config)
tables = client.query("select distinct table_name from dim_tables_unique_index").map { |h| h.values }.flatten
client.close

tables.each do |table_name|
  client = Mysql2::Client.new(config)
  columns = client.query("show columns from #{table_name}").map { |h| h['Field'] }.flatten
  client.close

  Dir.glob("./190315-tar.gz/*.sql").each do |database_path|
    database_name = database_path.scan(/gz\/(.*?).sql$/).flatten.first
    next if database_name != 'eziiot_db19'
    next unless database_name.start_with?("eziiot_")
    next if ['eziiot_main_db', 'eziiot_kpi_db'].include?(database_name)

    puts "insert ignore into eziiot_b9s_db.#{table_name}(`#{columns.join('`,`')}`) select `#{columns.join('`,`')}` from #{database_name}.#{table_name};"

    # next if File.exists?("./hrj/#{database_name}.import-err")
    # # puts "create database if not exists #{database_name};"
    # # puts "grant all privileges on #{database_name}.* to eziiot_user;"
    # puts "# #{database_name}"
    # # puts "sleep 2"
    # puts "mysql -h#{config[:host]} -u#{config[:username]} -p#{config[:password]} -P#{config[:port]} --default-character-set=utf8 #{database_name} < hrj/pro_add_all_table_column_0315.sql 2> hrj/#{database_name}.import-err"
    # puts ""
  end
end