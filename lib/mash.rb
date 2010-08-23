class Mash < Hash
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
    v = *v if v.one?
    super k.to_s.downcase.to_sym, v
  end
  
  def [](k)
    v = super(k.to_s.downcase.to_sym)
    yield v if block_given?
    v
  end
end

