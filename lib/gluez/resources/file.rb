resource :file do
  optional :chmod, :default => 644
  optional :chown
  
  ready!
  
  steps do |step|
    step.checks << "-f #{self.name}"
    step.code = "touch #{self.name}"
  end
  steps do |step|
    step.checks << %Q("\\$(stat -L --format=%a #{self.name})" = "#{self.chmod}")
    step.code = "chmod #{self.chmod} #{self.name}"
  end
  
  if self.chown
    steps do |step|
      step.checks << %Q("\\$(stat -L --format=%U:%G #{self.name})" = "#{self.chown}")
      step.code = "chown #{self.chown} #{self.name}"
    end
  end
  
end