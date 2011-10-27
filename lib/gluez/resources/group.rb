resource :group do
  mandatory :gid
  
  ready!
  
  steps do |step|
    step.checks << "$(cat /etc/group | grep ^#{self.name}: | wc -l) -eq 1"
    step.code = "groupadd --gid #{self.gid} #{self.name}"
  end
end