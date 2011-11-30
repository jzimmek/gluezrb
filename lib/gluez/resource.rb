module Gluez
  
  module Resources
  end
  
  # Resources are the building blocks of gluez. Each resource has a specification which list the attributes, their default values and the actual code to execute.
  # The code to execute is listed as separate steps. A step consist of a chunk of code and a check, which ensures the chunk of code has been executed correctly.
  # Complex checks can be broken down as multiple simple checks. These will be AND'ed later on.
  #
  # Resources will be executed as root per default. The special attribute user can be set, so that the resource will be executed as this user.
  class Resource

    # A Step consist of a chunk of code and a check, to ensure the code has been applied successfully.
    class Step
      attr_accessor :checks, :code
      def initialize
        @checks = []
      end
    end
    
    # The name of this resource
    attr_reader :name
    
    # The type of this resource
    attr_reader :type
    
    # A chunk of code which will be executed before any other code defined as steps
    attr_accessor :setup
    
    attr_reader :subscriptions
    
    def initialize(context, type, name, &block)
      @context = context
      @type = type.to_sym
      @name = name
      @steps = []
      
      @as_user = nil
      
      @notifies = []
      @subscriptions = []
      
      @mandatories = []
      @optionals = []
      
      # self.optional :user, :default => "root"
      self.optional :lazy, :default => false
      
      self.accessor :setup
    end
    
    def as_user(user)
      @as_user = user
    end
    
    def user
      @as_user || @context.user
    end
    
    def home_dir
      self.user == "root" ? "/root" : "/home/#{self.user}"
    end
    
    def validate!
      @mandatories.each do |it|
        raise "no value for mandatory attribute #{it}" if self.send(it).nil?
      end
    end
    
    def mandatory(name, opts={})
      @mandatories << name
      self.accessor(name)
    end

    def optional(name, opts={})
      @optionals << name
      self.accessor(name, opts[:default])
    end

    def accessor(name, default=nil)
      self.class.instance_eval do
        define_method(name) do |*args|
          if args.length == 0
            v = instance_variable_get("@#{name}")
            v.nil? ? default : v
          else
            instance_variable_set("@#{name}", args.first)
          end
        end
      end
    end
    
    def notify(type, name)
      @notifies << [type, name]
    end

    def subscribe(type, name)
      @subscriptions << [type, name]
    end
    
    def assign(name)
      self.send(name, $gluez.get(name))
    end
    
    # Creates a new step for this resource. This method is called within the specification of a resource and should not be called after this phase.
    def steps
      step = Gluez::Resource::Step.new
      yield(step)
      
      step.checks.each do |check|
        check.gsub!("\"", "\\\"")
      end
      
      @steps << step
    end
    
    # Returns this resource as a bash function. The function body contains all the steps checks/codes in the order as specified for this resource.
    # Test if the check part of a step is up2date. If not, execute the code of the step. If it is up2date now, continue with the next step, fail with an error otherwise.
    def generate(simulate)
      g = []
      
      fun = self.function_name
      
      g << "function #{fun} {"
      g << "su -l #{user} -c \"#{self.setup}\"" if self.setup

      if @steps.map{|s| s.checks}.flatten.empty?
        unless simulate
          g << "su -l #{user} -c \"#{@steps.map{|s| s.code}.join(' && ')}\""

          generate_success_or_failure(g, "echo \"[applied] - #{fun}\"") do
            g << "echo \"[not applied] - #{fun}\""
            g << "exit 1"
          end
          
          generate_notify_and_subscribe(g)
        end
      else
        generate_steps_checks(g, @steps)
        generate_success_or_failure(g, "echo \"[up2date] - #{fun}\"") do
          g << "echo \"[not up2date] - #{fun}\""

          unless simulate
            y = @steps.length
            if y > 1
              (0..@steps.length-1).to_a.each do |limit|
                generate_steps_checks(g, @steps[0..limit])
                x = limit + 1

                generate_success_or_failure(g, "echo \"[up2date] #{x}/#{y} - #{fun}\"") do
                  g << "echo \"[not up2date] #{x}/#{y} - #{fun}\""
                  g << "su -l #{user} -c \"#{@steps[limit].code}\""

                  generate_success_or_failure(g, "echo \"[applied] #{x}/#{y} - #{fun}\"") do
                    g << "echo \"[not applied] #{x}/#{y} - #{fun}\""
                    g << "exit 1"
                  end
                end
              end
            else
              g << "su -l #{user} -c \"#{@steps.first.code}\""

              generate_success_or_failure(g, "echo \"[applied] - #{fun}\"") do
                g << "echo \"[not applied] - #{fun}\""
                g << "exit 1"
              end
            end

            generate_notify_and_subscribe(g)

          end
        end
      end

      
      g << "}"
      g
    end
    
    def generate_notify_and_subscribe(g)
      @notifies.each do |run|
        type, name = run

        resource = @context.root.resources.detect{|r| r.type == type && r.name == name}
        raise "resource #{type} #{name} does not exist" unless resource

        g << resource.function_name
      end

      @context.root.resources.select{|r| r.subscriptions.include?([@type, @name])}.each do |resource|
        g << resource.function_name
      end
    end
    
    def generate_steps_checks(g, steps)
      g << steps.map do |step|
        step.checks
      end.flatten.map do |check|
        "su -l #{user} -c \"test #{check}\""
      end.join(" && ")
    end
    
    def generate_success_or_failure(g, success)
      g << "if [[ $? -eq 0 ]]; then"
      g << success
      g << "else"
      yield
      g << "fi"
    end
    
    # Returns a bash-compatible function name for this resource
    def function_name
      "#{user}_#{self.type}_#{self.name}".
        gsub('/', '_').
        gsub(':', '_').
        gsub("@", "_").
        gsub("~", "_").
        gsub(" ", "_").
        gsub(".", "_")     
    end
    
  end
end