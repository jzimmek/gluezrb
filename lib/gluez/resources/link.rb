resource :link do
  mandatory   :target
  
  ready!
  
  steps do |step|
    step.checks << "-L #{self.name}"
    step.checks << "\\$(file #{self.name} | grep \"#{self.name.gsub('~', '\$HOME')}: symbolic link to \\\\\\`#{self.target.gsub('~', '\$HOME')}'\" | wc -l) -eq 1"
    
    step.code = "ln -f -s #{self.target} #{self.name}"
  end
end