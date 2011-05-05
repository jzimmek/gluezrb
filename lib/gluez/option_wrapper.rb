module Gluez
  class OptionWrapper
    def initialize(options)
      @options = options
    end
    
    def key?(key)
      @options.key?(key)
    end
    
    def [](name, default=nil)
      value = @options[name]
      if value
        value
      else
        if default
          default
        else
          raise "missing option: #{name}"
        end
      end
    end
  end
end