module Enumerable
  def index_by(&block)
    each_with_object({}){|object, hsh|
      index = block.call(object)
      raise "Non-unique index `#{index}`"  if hsh.has_key?(index)
      hsh[index] = object
    }
  end

  def select_unique_by(&block)
    group_by(&block).select{|k,vs| vs.size == 1 }.values.flatten
  end

  def reject_unique_by(&block)
    group_by(&block).reject{|k,vs| vs.size == 1 }.values.flatten
  end
end

# doesn't work if there are duplicate keys

# doesn't work if there are duplicate keys
def full_join_by(collection_1, collection_2, drop_nil: true, key_proc_1: nil, key_proc_2: nil, &key_proc)
  key_proc_1 ||= key_proc
  key_proc_2 ||= key_proc
  if drop_nil
    collection_1 = collection_1.select(&key_proc_1)
    collection_2 = collection_2.select(&key_proc_2)
  end
  collection_1_by_key = collection_1.index_by(&key_proc_1)
  collection_2_by_key = collection_2.index_by(&key_proc_2)
  keys = (collection_1_by_key.keys + collection_2_by_key.keys).uniq
  keys.map{|key|
    obj_1 = collection_1_by_key[key]
    obj_2 = collection_2_by_key[key]
    [key, obj_1, obj_2]
  }
end

def left_join_by(collection_1, collection_2, drop_nil: true, key_proc_1: nil, key_proc_2: nil, &key_proc)
  full_join_result = full_join_by(collection_1, collection_2, drop_nil: drop_nil, key_proc_1: key_proc_1, key_proc_2: key_proc_2, &key_proc)
  full_join_result.select{|k, obj_1, obj_2| obj_2 }
end

# doesn't work if there are duplicate keys
def inner_join_by(collection_1, collection_2, drop_nil: true, key_proc_1: nil, key_proc_2: nil, &key_proc)
  full_join_result = full_join_by(collection_1, collection_2, drop_nil: drop_nil, key_proc_1: key_proc_1, key_proc_2: key_proc_2, &key_proc)
  full_join_result.select{|k, obj_1, obj_2| obj_1 && obj_2 }
end

def left_unjoined_by(collection_1, collection_2, drop_nil: true, key_proc_1: nil, key_proc_2: nil, &key_proc)
  full_join_result = full_join_by(collection_1, collection_2, drop_nil: drop_nil, key_proc_1: key_proc_1, key_proc_2: key_proc_2, &key_proc)
  full_join_result.select{|k, obj_1, obj_2| obj_1 && !obj_2 }.map{|k, obj_1, _| [k, obj_1] }
end

def right_unjoined_by(collection_1, collection_2, drop_nil: true, key_proc_1: nil, key_proc_2: nil, &key_proc)
  full_join_result = full_join_by(collection_1, collection_2, drop_nil: drop_nil, key_proc_1: key_proc_1, key_proc_2: key_proc_2, &key_proc)
  full_join_result.select{|k, obj_1, obj_2| !obj_1 && obj_2 }.map{|k, _, obj_2| [k, obj_2] }
end
