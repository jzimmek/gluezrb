require 'erb'
require 'base64'

resource :transfer do

  mandatory     :content
  optional      :chmod, :default => 644
  
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
  
  data = ERB.new(self.content).result(vars.get_binding)
  base64 = Base64.encode64(data)
  
  setup "cat >~/.gluez_transfer <<\\DATA
#{base64.strip}
DATA"
  
  steps do |step|
    step.checks << "-f #{self.name}"
    step.code = "touch #{self.name}"
  end
  steps do |step|
    step.checks << %Q("\\$(stat -L --format=%a #{self.name})" = "#{self.chmod}")
    step.code = "chmod #{self.chmod} #{self.name}"
  end
  steps do |step|
    step.checks << %Q("\\$(cat ~/.gluez_transfer | base64 -i -d - | md5sum - | awk '{print \\$1}')" = "\\$(md5sum #{self.name} | awk '{print \\$1}')")
    step.code = "chmod +w #{self.name} && cat ~/.gluez_transfer | base64 -i -d - > #{self.name} && chmod #{self.chmod} #{self.name}"
  end

end