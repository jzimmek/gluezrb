resource :path do
  ready!
  
  steps do |step|
    link = self.name.gsub('/', '_').gsub('~', "/home/#{self.user}/.gluez/path/")
    target = self.name.gsub('~', "/home/#{self.user}")
    
    step.checks << "-L #{link}"
    step.checks << "\\$(ls -al #{link} | awk '{print \\$10}' | grep #{target} | wc -l) -eq 1"
    
    step.code = "ln -f -s #{self.name} #{link}"
  end
end