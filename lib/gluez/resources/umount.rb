resource :umount do
  ready!
  
  steps do |step|
    step.checks << "\\$(mount | grep \"on #{self.name} type\" | wc -l) -eq 0"
    step.code = "umount #{self.name}"
  end
end