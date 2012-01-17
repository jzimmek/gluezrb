resource :exec do
  ready!

  steps do |step|
    step.checks << "! -f #{self.name}"
    step.code = self.name
  end
end