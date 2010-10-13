require 'thread'

class Proc
  def bind(object)
    block, time = self, Time.now
    (class << object; self end).class_eval do
      method_name = "__bind_#{time.to_i}_#{time.usec}"
      define_method(method_name, &block)
      method = instance_method(method_name)
      remove_method(method_name)
      method
    end.bind(object)
  end
end

class Object
  unless defined? instance_exec # 1.9
    def instance_exec(*arguments, &block)
      block.bind(self)[*arguments]
    end
  end
end

module Burke
  class Holder < Hash
    class CircularReadError < RuntimeError ; end
    
    def holder_instance_exec? ; true ; end
    
    class << self
      attr_accessor :defaults
      
      def inherited clazz
        clazz.instance_eval do
          @fields = []
          @defaults = {}
        end
      end
      
      def field name, &block
        name = String(name)
        @fields << name
        @fields.uniq!
        @defaults[name] = block if block_given?
      end
      
      def fields *names
        names.each { |name| field name }
      end
      
      def field_exists? name
        @fields.include? name
      end
      
      def [](hash)
        new.merge hash
      end
    end
    
    def initialize *args, &block
      if block_given?
        self.instance_exec self, &block
      else
        super
      end
      
      @currently_getting = []
      @currently_getting_mutex = Mutex.new
    end
    
    def to_hash
      out = {}
      keys.concat(self.class.defaults.keys).uniq.each do |k|
        out[k] = Holder === self[k] ? self[k].to_hash : self[k]
      end
      out
    end
    
    def [](key)
      key = normalize_key key
      assert_field_exists! key
      id = "#{key}-#{Thread.current.object_id}"
      @currently_getting_mutex.synchronize do
        if @currently_getting.include? id
          raise CircularReadError.new "circular read for field '#{key}'" 
        end
        @currently_getting << id
      end
      val = if key? key
        super
      elsif self.class.defaults.key? key
        self.instance_eval(&self.class.defaults[key])
      else
        nil
      end
      @currently_getting_mutex.synchronize do
        @currently_getting.delete id
      end
      val
    end
    
    def []=(key, value)
      key = normalize_key key
      assert_field_exists! key
      super
    end
    
    def merge! other
      other.each do |k, v|
        self[k] ||= v
      end
      
      nil
    end
    
    def merge other
      holder = self.class.new
      
      self.each do |k, v|
        holder[k] = v
      end
      
      other.each do |k, v|
        holder[k] ||= v
      end
      
      holder
    end
    
    def delete key
      super normalize_key(key)
    end
    
    def method_missing name, *args, &block
      base, ending = *String(name).match(/(\w*)([!?=]?)/).to_a[1..-1]
      key = normalize_key(base)
      case ending
      when '?'
        if field_exists? key
          !!self[key]
        else
          super
        end
      when '='
        if field_exists? key
          self[key] = *args
        else
          super
        end
      when ''
        if field_exists? key
          if args.empty?
            v = self[key]
            if block_given?
              if v.respond_to? 'holder_instance_exec?' and v.holder_instance_exec?
                v.instance_exec v, &block
              else
                yield v
              end
            end
            v
          else
            self[key] = *args
          end
        else
          super
        end
      else
        super
      end
    end
    
    def normalize_key key
      String(key)
    end
    
    def field_exists? name
      self.class.field_exists? name
    end
    
    def assert_field_exists! name
      unless field_exists? name
        raise NoMethodError, "field '#{name}' is not defined for this Holder."
      end
    end
  end
end

