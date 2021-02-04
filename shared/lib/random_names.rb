require "sqlite3"

# Open a database
$dataset_names_DB = SQLite3::Database.new('dataset_names.db')
def take_dataset_name!
  db = $dataset_names_DB
  while true
    begin
      db.transaction(:exclusive) {
        ds_id, ds_name = db.execute("SELECT id, name FROM dataset_names WHERE status == 'not-used' LIMIT 1").first
        db.execute("UPDATE dataset_names SET status = 'used' WHERE id == (?)", [ds_id])
        return ds_name
      }
    rescue => e
      $stderr.puts("Error while trying to generate dataset name")
      $stderr.puts(e)
      sleep(rand * 5)
      $stderr.puts("Retry to generate dataset name")
    end
  end
end
