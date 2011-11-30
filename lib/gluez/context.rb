module Gluez
  # A context in gluez is a unit of work. It contains one or multiple resources. Context-wide variables can set/get as properties.
  # A context can include a recipe, which is an isolated context of it's own. We can set properties of a recipe from the outer context.
  # This enables us to write modular and reusable recipes.
  class Context
    
    # An array of all resources in this context
    attr_reader :resources
    
    # A reference to the outer context
    attr_reader :parent, :included_user_contexts
    
    def initialize(parent=nil, name=nil, user=nil, &block)
      @parent = parent
      @name = name
      @user = user
      
      @resources = []
      @properties = {}
      
      @included_user_contexts = []
      
      $gluez = self
      
      self.include_user! "root" if self == self.root
      
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
    
    def user
      if @user
        @user
      else
        @parent ? @parent.user : nil
      end
    end
    
    def home_dir
      self.user == "root" ? "/root" : "/home/#{self.user}"
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
    
    def include_library_recipe(library_dir, name, &block)
      raise "include_recipe is only allowed in user context" if self == self.root
      Gluez::Context.new(self, name, nil) do |c|
        c.instance_eval(&block) if block
        load "#{library_dir}/recipes/#{name}/#{name}.rb"
      end
    end
    
    # Includes a recipe. A new context will be created. The passed block will be executed in the scope of the new context.
    def include_recipe(name, &block)
      self.include_library_recipe(File.dirname($0), name, &block)
    end

    def include_user!(name, &block)
      self.include_user(name, true, &block)
    end
      
    def include_user(name, failsafe=false, &block)
      raise "include_user is only allowed in root context" unless self == self.root
      Gluez::Context.new(self, name, name) do |c|
        if block
          c.instance_eval(&block) 
        end
        
        c.root.included_user_contexts << c
        
        f = "#{File.dirname($0)}/users/#{name}.rb"
        
        if File.exist?(f)
          load(f)
        else
          raise "could not find user context file #{f}" unless failsafe
        end
        
      end
    end
    
    # Loops through all resources, collect their generated code, format and return it.
    def generate(simulate)
      code = "#!/bin/bash"

      root_user_context = @included_user_contexts.detect{|ctx| ctx.user == "root"}
      raise "no root user context could be found" unless root_user_context
      
      user_contexts = @included_user_contexts - [root_user_context]

      existing_resources = Array.new(@resources)

      root_user_context.instance_eval do |ctx|
        user_contexts.each do |user_ctx|
          create_group(user_ctx.user) do
            gid user_ctx.get(:uid)
          end
        
          create_user(user_ctx.user) do
            uid user_ctx.get(:uid)
            gid user_ctx.get(:uid)
          end
          
          ['.gluez', '.gluez/path', 'tmp', 'backup', 'bin', '.ssh'].each do |dir_name|
            dir(dir_name) do
              as_user user_ctx.user
            end
          end
          
          if user_ctx.get(:authorized_keys)
            transfer "~/.ssh/authorized_keys" do
              as_user user_ctx.user
              chmod 400
              content user_ctx.get(:authorized_keys).join("\n")
            end
          end
            
          transfer "~/.profile" do
            as_user  user_ctx.user
            chmod   644
            content File.read("#{File.dirname(__FILE__)}/templates/profile.erb")
          end
          
          if user_ctx.get(:sudo)
            transfer "/etc/sudoers.d/#{user_ctx.user}" do
              chmod 440
              content "#{user_ctx.user} ALL=(ALL) NOPASSWD: ALL"
            end
          end
          
        end
      end
      
      # sort resources to always create users/groups first
      @resources = (@resources - existing_resources) + existing_resources
      
      code += "\n" + @resources.collect do |res|
        res.generate(simulate).join("\n")
      end.join("\n")

      code += "\n" + @resources.select{|r| !r.lazy}.collect do |res|
        res.function_name
      end.join("\n")
      
      puts Gluez::format(code)
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