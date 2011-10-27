resource :mount do
  mandatory   :type
  mandatory   :options
  mandatory   :device
  
  optional    :options
  
  ready!
  
  steps do |step|
    step.checks << "\\$(mount | grep \"on #{self.name} type\" | wc -l) -eq 1"
    
    cmd = "mount -t #{self.type}"
    cmd = "#{cmd} -o #{self.options}" if self.options
    cmd = "#{cmd} #{self.device} #{self.name}"
    
    step.code = cmd
  end
end