require 'sqlite3'
require 'json'

# spo = (subject, predicate, object) triple

def create_spo_cache(db_filename)
  db ||= SQLite3::Database.new(db_filename)
  db.execute(<<-EOS
    CREATE TABLE IF NOT EXISTS spo_store(id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT, property TEXT, json_value TEXT);
    CREATE UNIQUE INDEX IF NOT EXISTS sp_uniq ON spo_store(entity, property);
    EOS
  )
  db
end

def store_to_spo_cache(s,p,o)
  @spo_db ||= create_spo_cache('dataset_stats_spo_cache.db')
  @spo_db.execute("INSERT INTO spo_store(entity, property, json_value) VALUES (?,?,?)", [s,p,JSON.dump(o)] )
end

def load_from_spo_cache(s,p)
  @spo_db ||= create_spo_cache('dataset_stats_spo_cache.db')
  results = @spo_db.execute("SELECT json_value FROM spo_store WHERE entity = ? AND property = ?", [s,p])
  raise 'Uniqueness constraint violated'  if results.size > 1
  return nil  if results.empty?
  result = results[0]
  json_value = result[0]
  JSON.parse(json_value)
end
