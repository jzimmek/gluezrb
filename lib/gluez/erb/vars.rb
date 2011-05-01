module Gluez
  class Vars
    def initialize(hash={})
      hash.each_pair do |key, val|
        self.metaclass.send(:define_method, key) do
          val
        end
      end
    end
    
    def metaclass
      class << self; self; end
    end

    def get_binding
      binding
    end
  end
end