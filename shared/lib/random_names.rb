require "sqlite3"

# Open a database
$dataset_names_DB = SQLite3::Database.new('dataset_names.db')
def take_dataset_name!
  db = $dataset_names_DB
  ds_name = nil
  max_num_attempts = 10
  num_attempts = max_num_attempts
  while ds_name.nil? && num_attempts > 0
    begin
      db.transaction(:exclusive) {
        ds_id, ds_name = db.execute("SELECT id, name FROM dataset_names WHERE status == 'not-used' LIMIT 1").first
        if ds_name
          db.execute("UPDATE dataset_names SET status = 'used' WHERE id == (?)", [ds_id])
          return ds_name
        end
      }
    rescue
      num_attempts -= 1
      sleep(rand * 5) # wait and retry
    end
  end
  count_used, = db.execute("SELECT COUNT(*) FROM dataset_names WHERE status == 'used'").first
  count_free, = db.execute("SELECT COUNT(*) FROM dataset_names WHERE status == 'not-used'").first
  raise "take_dataset_name!: #{max_num_attempts} attempts failed. There are #{count_free} unused names in the pool, while #{count_used} names used."
end
