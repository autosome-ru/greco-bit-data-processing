class Node
  attr_accessor :value, :children, :parent, :key
  def initialize(value: nil, children: nil, parent: nil, key: nil)
    @value = value
    @parent = parent
    @key = key
    @children = children || {}
  end

  def path
    result = []
    node = self
    while node
      result << node.key
      node = node.parent
    end
    result[0...-1].reverse
  end

  def [](*keys)
    keys.reduce(self){|node, key| node.children[key] }
  end

  def root?
    parent.nil?
  end

  def leaf?
    children.empty?
  end

  def each_node_downwards(&block)
    return enum_for(:each_node_downwards)  unless block_given?
    yield self
    children.each{|k,v| v.each_node_downwards(&block) }
  end

  def each_node_upwards(&block)
    return enum_for(:each_node_upwards)  unless block_given?
    children.each{|k,v| v.each_node_upwards(&block) }
    yield self
  end

  alias_method :each_node, :each_node_downwards

  def each_leaf(&block)
    return enum_for(:each_leaf)  unless block_given?
    yield self  if self.leaf?
    children.each{|k,v| v.each_leaf(&block) }
  end

  def each_node_bfs(&block)
    return enum_for(:each_node_bfs)  unless block_given?
    cur_layer = [self]
    while !cur_layer.empty?
      cur_layer.each{|node| yield node }
      cur_layer = cur_layer.flat_map{|node| node.children.values }
    end
  end

  def self.construct_tree(scheme, parent: nil, key: nil)
    case scheme
    when Hash
      Node.new(value: nil, parent: parent, key: key).tap{|node|
        node.children = scheme.map{|k, v| [k, construct_tree(v, parent: node, key: k)] }.to_h
      }
    when Array
      Node.new(value: nil, parent: parent, key: key).tap{|node|
        node.children = scheme.map{|k| [k, Node.new(value: nil, parent: node, key: k, children: {})] }.to_h
      }
    end
  end
end
