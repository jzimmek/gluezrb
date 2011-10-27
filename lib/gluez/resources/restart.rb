resource :restart do
  ready!
  steps do |step|
    step.code = "service #{self.name} restart"
  end
end