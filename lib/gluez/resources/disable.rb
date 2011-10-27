resource :disable do
  ready!
  
  steps do |step|
    step.checks << "\\$(update-rc.d -n -f #{self.name} remove | grep '/etc/rc' | wc -l) -eq 0"
    step.code = "/usr/sbin/update-rc.d -f #{self.name} remove"
  end
end