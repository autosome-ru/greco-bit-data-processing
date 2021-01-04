module Enumerable
  def index_by(&block)
    each_with_object({}){|object, hsh|
      index = block.call(object)
      raise "Non-unique index `#{index}`"  if hsh.has_key?(index)
      hsh[index] = object
    }
  end
end
