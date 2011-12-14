resource :restart do
  ready!
  
  self.as_user "root"
  
  steps do |step|
    step.code = "service #{self.name} restart"
  end
end