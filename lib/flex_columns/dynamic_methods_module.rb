module FlexColumns
  class DynamicMethodsModule < ::Module
    def initialize(target_class, name, &block)
      raise ArgumentError, "Target class must be a Class, not: #{target_class.inspect}" unless target_class.kind_of?(Class)
      raise ArgumentError, "Name must be a Symbol or String, not: #{name.inspect}" unless name.kind_of?(Symbol) || name.kind_of?(String)

      @target_class = target_class
      @name = name.to_sym

      @target_class.const_set(@name, self)
      @target_class.send(:include, self)

      @methods_defined = { }

      super(&block)
    end

    def remove_all_methods!
      @methods_defined.keys.each { |name| remove_method(name) }
    end

    def define_method(name, &block)
      name = name.to_sym
      super(name, &block)
      @methods_defined[name] = true
    end
  end
end