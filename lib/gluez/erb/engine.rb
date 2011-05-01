require 'erb'
require 'base64'

require 'gluez/erb/vars'

module Gluez
  module Erb
    class Engine
      def self.parse(content, vars={})
        v = Gluez::Vars.new(vars)
      
        erb = ERB.new(content)
        content2 = erb.result(v.get_binding)
      
        Base64.encode64(content2)
      end
    end
  end
end