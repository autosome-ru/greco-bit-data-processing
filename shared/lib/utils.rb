def take_the_only(vs)
  raise "Size of #{vs} should be 1 but was #{vs.size}" unless vs.size == 1
  vs[0]
end

class Array
  def take_the_only
    take_the_only(self)
  end
end
