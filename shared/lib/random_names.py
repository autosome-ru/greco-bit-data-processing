import random
import sqlite3
import namegenerator

DB_NAME = 'dataset_names.db'
conn = sqlite3.connect(DB_NAME)
cursor = conn.cursor()

def gen_names(num_names):
    names = set()
    while len(names) < num_names:
        names.add(namegenerator.gen())
    names = list(names)
    random.shuffle(names)
    return names

def create_tables():
    cursor.execute("CREATE TABLE IF NOT EXISTS dataset_names (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR UNIQUE, status VARCHAR default 'not-used')")
    cursor.execute("CREATE INDEX IF NOT EXISTS statuses ON dataset_names (status)")
    conn.commit()

# Second invocation of `fill_db` can raise due to name duplicates
def fill_db(num_names):
    names = gen_names(num_names)
    cursor.executemany("INSERT INTO dataset_names(name) VALUES (?)", [(name,)  for name in names])
    conn.commit()

# to be used in other scripts
def take_dataset_name():
    cursor.execute("SELECT id, name FROM dataset_names WHERE status == 'not-used' LIMIT 1")
    ds_id, ds_name = cursor.fetchone()
    cursor.execute("UPDATE dataset_names SET status = 'used' WHERE id == (?)", (ds_id,))
    conn.commit()
    return ds_name

if __name__ == '__main__':
    create_tables()
    fill_db(100000)
    conn.close()
