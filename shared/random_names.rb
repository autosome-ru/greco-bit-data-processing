require "sqlite3"

# Open a database
$dataset_names_DB = SQLite3::Database.new('dataset_names.db')
def take_dataset_name!
  ds_id, ds_name = $dataset_names_DB.execute("SELECT id, name FROM dataset_names WHERE status == 'not-used' LIMIT 1").first
  $dataset_names_DB.execute("UPDATE dataset_names SET status = 'used' WHERE id == (?)", [ds_id])
  ds_name
end
