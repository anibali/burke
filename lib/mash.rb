class Mash < Hash
  def initialize *args, &block
    super
  end
  
  def method_missing name, *args, &block
    if name.to_s =~ /(.*)=/
      self.[]=($1, *args, &block)
    else
      if args.empty?
        self.[](name, &block)
      else
        self.[]=(name, *args, &block)
      end
    end
  end
  
  def []=(k, *v)
    k = k.to_s.downcase.to_sym
    v = *v if v.one?
    v = setter_filters[k].call v if setter_filters.has_key? k
    super k, v
  end
  
  def [](k)
    v = super(k.to_s.downcase.to_sym)
    v = getter_filters[k].call v if getter_filters.has_key? k
    yield v if block_given?
    v
  end
  
  def setter_filter key, &block
    setter_filters[key.to_sym] = block
  end
  
  def getter_filter key, &block
    getter_filters[key.to_sym] = block
  end
  
  def setter_filters
    @setter_filters ||= {}
  end
  
  def getter_filters
    @getter_filters ||= {}
  end
end

