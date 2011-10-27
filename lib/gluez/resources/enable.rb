resource :enable do
  ready!
  
  steps do |step|
    step.checks << "\\$(update-rc.d -n -f #{self.name} remove | grep '/etc/rc' | wc -l) -gt 0"
    step.code = "/usr/sbin/update-rc.d #{self.name} defaults"
  end
end