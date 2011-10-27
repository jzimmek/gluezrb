resource :dir do
  optional :chmod, :default => 755
  
  ready!
  
  steps do |step|
    step.checks << "-d #{self.name}"
    step.code = "mkdir #{self.name}"
  end
  steps do |step|
    step.checks << %Q("\\$(stat -L --format=%a #{self.name})" = "#{self.chmod}")
    step.code = "chmod #{self.chmod} #{self.name}"
  end
end