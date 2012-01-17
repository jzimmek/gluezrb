resource :start do
  ready!
  
  self.as_user "root"
  
  setup "service --status-all 1>/tmp/gluez.tmp 2>&1"
  steps do |step|
    step.checks << %Q("\\$(grep #{self.name} /tmp/gluez.tmp | wc -l)" = "1")
    step.checks << %Q("\\$(service #{self.name} status | grep -E 'is running|start/running' | wc -l)" = "1")
    step.code = "service #{self.name} start"
  end
end