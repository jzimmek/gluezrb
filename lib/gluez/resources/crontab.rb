require 'erb'
require 'base64'

resource :crontab do

  mandatory     :content
  
  instance_variable_set("@vars", {})
  def var(name, value)
    @vars[name] = value
  end
  
  ready!
  
  res = self
  vars = Object.new
  
  vars.class.class_eval do
    res.instance_variable_get("@vars").each_pair do |key, val|
      next unless val
      define_method key do
        val
      end
    end
    define_method :get_binding do
      binding
    end
  end
  
  data = ERB.new(self.content).result(vars.get_binding).multiline_strip
  base64 = Base64.encode64(data + "\n")
  
  setup "cat >~/.gluez_transfer <<\\DATA
#{base64}
DATA"
  
  steps do |step|
    step.checks << %Q("\\$(cat ~/.gluez_transfer | base64 -d - | md5sum - | awk '{print \\$1}')" = "\\$(crontab -l | md5sum - | awk '{print \\$1}')")
    step.code = "cat ~/.gluez_transfer | base64 -d - | crontab"
  end

end