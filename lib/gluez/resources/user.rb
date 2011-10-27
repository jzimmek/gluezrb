resource :user do
  mandatory   :uid
  mandatory   :gid

  ready!
  
  steps do |step|
    step.checks << "$(cat /etc/passwd | grep ^#{self.name}: | wc -l) -eq 1"
    step.code = "useradd --create-home --uid #{self.uid} --gid #{self.gid} --shell /bin/bash #{self.name}"
  end
end