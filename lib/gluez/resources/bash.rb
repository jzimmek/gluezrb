resource :bash do
  mandatory :code
  mandatory :not_if
  optional  :clean
  
  ready!

  steps do |step|
    step.checks << self.not_if
    step.code = self.code
  end
end