def take_the_only(vs)
  raise "Size of #{vs} should be 1 but was #{vs.size}" unless vs.size == 1
  vs[0]
end

def take_the_only_or_default(vs, default: nil)
  raise "Size of #{vs} should be 1 or 0 but was #{vs.size}" if vs.size > 1
  vs.fetch(0, default)
end

class Array
  def take_the_only
    raise "Size should be 1 but was #{size}" unless size == 1
    self[0]
  end

  def take_the_only_or_default(default: nil)
    raise "Size should be 1 or 0 but was #{size}" if size > 1
    self.fetch(0, default)
  end
end
