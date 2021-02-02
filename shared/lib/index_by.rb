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
