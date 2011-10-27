module Gluez
  # A context in gluez is a unit of work. It contains one or multiple resources. Context-wide variables can set/get as properties.
  # A context can include a recipe, which is an isolated context of it's own. We can set properties of a recipe from the outer context.
  # This enables us to write modular and reusable recipes.
  class Context
    
    # An array of all resources in this context
    attr_reader :resources
    
    # A reference to the outer context
    attr_reader :parent
    
    def initialize(parent=nil, name=nil, &block)
      @parent = parent
      @name = name
      
      @resources = []
      @properties = {}
      
      $gluez = self
      instance_eval(&block) if block
      
      if self.root == self
        self.generate($simulate == true)
      else
        $gluez = parent
      end
    end
    
    # Returns the outer most context
    def root
      self.parent ? self.parent.root : self
    end
    
    def default(name, name2)
      unless @properties.key?(name)
        if name2.is_a?(Symbol)
          set(name, get(name2))
        else
          set(name, name2)
        end
      end
    end
    
    def expect(name)
      raise "missing #{name}" unless get(name)
    end
    
    def locate(resource)
      File.dirname($0) + (@name.nil? ? "" : "/recipes/#{@name}") + "/files/#{resource}"
    end
    
    def read(resource)
      File.read $gluez.locate(resource)
    end
    
    # Set a property value
    def set(name, value)
      @properties[name] = value
    end
    
    # Get a property value
    def get(name)
      @properties[name]
    end
    
    # Includes a recipe. A new context will be created. The passed block will be executed in the scope of the new context.
    def include(name, &block)
      Gluez::Context.new(self, name) do |c|
        c.instance_eval(&block) if block
        load "#{File.dirname($0)}/recipes/#{name}/#{name}.rb"
      end
    end
    
    # Loops through all resources, collect their generated code, format and return it.
    def generate(simulate)
      code = "#!/bin/bash"
            
      code += "\n" + @resources.collect do |res|
        res.generate(simulate).join("\n")
      end.join("\n")

      code += "\n" + @resources.select{|r| !r.lazy}.collect do |res|
        res.function_name
      end.join("\n")
      
      code = Gluez::format(code)
      
      if Gluez.options.include?("--ssh")
        code64 = Base64.encode64(code)

        cmd = %(code=\\"#{code64.strip}\\" && echo \\\$code | base64 -i -d - | /bin/bash)
        ssh = "ssh -t whale01 \"sudo su -l root -c '#{cmd}'\""
        
        puts ssh
      else
        puts code
      end
      
    end
    
    def self.load_resources
      dirs = [File.dirname($0), File.dirname(__FILE__)].collect{|d| "#{d}/resources"}

      dirs.each do |dir|
        next unless File.exist?(dir)
        Dir.glob(dir + "/*") do |file|
          require file
        end
      end
    end

    def self.register(method_name, &block)
      define_method method_name do |name, &block2|
        res = Gluez::Resource.new(self, method_name, name)

        res.class.class_eval do
          define_method("ready!".to_sym) do
            res.instance_eval(&block2) if block2
            res.validate!
          end
        end
        
        res.instance_eval(&block)

        self.root.resources << res
      end
    end
    
  end
end