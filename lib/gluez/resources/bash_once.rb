resource :bash_once do
  mandatory :code
  
  ready!
  
  steps do |step|
    step.checks << "-f ~/.gluez/bash_once_#{self.function_name}"
    step.code = "#{self.code.strip} && touch ~/.gluez/bash_once_#{self.function_name}"
  end
end