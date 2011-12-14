require 'base64'

resource :upstart do
  optional    :start_on,  :default => "runlevel [2]"
  optional    :stop_on,   :default => "runlevel [016]"
  optional    :fork,      :default => false
  mandatory   :code
  
  ready!
  
  self.as_user "root"

  script = <<-EOF
    description "#{self.name}"

    start on #{self.start_on}
    stop on #{self.stop_on}

    console owner

    #{self.fork ? 'expect fork' : ''}
    respawn

    exec #{self.code}
  EOF
  
  script64 = Base64.encode64(script.multiline_strip)

  setup "cat >~/.gluez_transfer <<\\DATA
#{script64.strip}
DATA"
  
  steps do |step|
    step.checks << "-f /etc/init/#{self.name}.conf"
    step.code = "touch /etc/init/#{self.name}.conf"
  end
  steps do |step|
    step.checks << %Q("\\$(cat ~/.gluez_transfer | base64 -i -d - | md5sum - | awk '{print \\$1}')" = "\\$(md5sum /etc/init/#{self.name}.conf | awk '{print \\$1}')")
    step.code = "cat ~/.gluez_transfer | base64 -i -d - > /etc/init/#{self.name}.conf"
  end
  steps do |step|
    step.checks << "-L /etc/init.d/#{self.name}"
    step.code = "ln -s /lib/init/upstart-job /etc/init.d/#{self.name}"
  end
  
end