resource :package do
  ready!
  steps do |step|
    step.checks << "\\$(apt-cache policy #{self.name} | grep Installed | wc -l) -eq 1"
    step.checks << "\\$(apt-cache policy #{self.name} | grep Installed | grep '(none)' | wc -l) -eq 0"
    step.code = "apt-get install #{self.name} --yes"
  end
end