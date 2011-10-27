resource :gem do
  mandatory :version
  
  ready!
  
  steps do |step|
    step.checks << "\\$(gem list | awk '{print \\$1}' | grep ^#{self.name}$ | wc -l) -eq 1"
    step.code = "gem install #{self.name} --version #{self.version} --user-install --no-rdoc --no-ri"
  end
end